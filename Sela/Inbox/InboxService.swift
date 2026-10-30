import AppKit
import Combine
import Foundation

enum InboxAccess: Equatable {
    case disabled
    case needsPermission
    case reading
    case paused
    case unavailable
}

enum InboxObserverStatus: Equatable {
    case reading
    case permissionRequired
    case stopped
}

@MainActor
protocol InboxObserving: AnyObject {
    var onReading: (@MainActor (InboxBannerReading) -> Void)? { get set }
    var onStatus: (@MainActor (InboxObserverStatus) -> Void)? { get set }
    func authorizationStatus() -> InboxAccess
    func requestAccessibility()
    func start(sources: Set<InboxSource>)
    func stop()
}

/// In-memory only. Live capture is experimental and off by default.
@MainActor
final class InboxService: ObservableObject {
    static let shared = InboxService(observer: AccessibilityBannerObserver())

    @Published private(set) var items: [InboxItem] = []
    @Published private(set) var featureEnabled = false
    @Published private(set) var paused = false
    @Published private(set) var sources: Set<InboxSource> = []
    @Published private(set) var access: InboxAccess = .disabled
    @Published private(set) var statusMessage: String?

    private let observer: InboxObserving
    private let now: () -> Date
    private var recent: [String: Date] = [:]
    private var cancellables = Set<AnyCancellable>()

    init(observer: InboxObserving, now: @escaping () -> Date = Date.init) {
        self.observer = observer
        self.now = now

        observer.onReading = { [weak self] reading in
            self?.accept(reading)
        }
        observer.onStatus = { [weak self] status in
            self?.apply(status)
        }

        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                Task { @MainActor in self?.refreshAccess() }
            }
            .store(in: &cancellables)
    }

    var unreadCount: Int { items.filter { !$0.isRead }.count }

    func setEnabled(_ enabled: Bool) {
        guard enabled != featureEnabled else { return }

        featureEnabled = enabled
        paused = false
        statusMessage = nil
        if enabled {
            startReading()
        } else {
            observer.stop()
            access = .disabled
        }
    }

    func requestAccessibility() {
        guard featureEnabled else { return }

        observer.requestAccessibility()
        if observer.authorizationStatus() == .reading {
            startReading()
        } else {
            access = .needsPermission
            statusMessage = "Aktifkan Sela di System Settings › Privacy & Security › Accessibility."
        }
    }

    func setPaused(_ paused: Bool) {
        guard featureEnabled, paused != self.paused else { return }

        self.paused = paused
        if paused {
            observer.stop()
            access = .paused
            statusMessage = nil
        } else {
            startReading()
        }
    }

    func setSource(_ source: InboxSource, enabled: Bool) {
        guard source.isExperimentalSource else { return }

        var updated = sources
        if enabled {
            updated.insert(source)
        } else {
            updated.remove(source)
        }
        sources = updated

        guard featureEnabled, !paused else { return }
        startReading()
    }

    func toggleSource(_ source: InboxSource) {
        setSource(source, enabled: !sources.contains(source))
    }

    func markAllRead() {
        guard unreadCount > 0 else { return }
        items = items.map { item in
            var item = item
            item.isRead = true
            return item
        }
    }

    func clear() {
        items = []
        statusMessage = nil
    }

    func handle(url: URL) {
        guard let reading = InboxURL.reading(from: url) else { return }
        accept(reading, isSimulation: true)
    }

    func addSimulation() {
        accept(
            InboxBannerReading(
                source: .simulation,
                sender: "Sela",
                title: "Notifikasi uji",
                body: "Contoh isi Inbox untuk menguji tampilan."
            ),
            isSimulation: true
        )
    }

    func open(_ source: InboxSource) {
        guard let bundle = source.bundleIdentifier,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundle)
        else {
            statusMessage = "\(source.displayName) tidak ditemukan di Mac ini."
            return
        }

        NSWorkspace.shared.openApplication(at: url, configuration: .init()) { _, _ in }
    }

    func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }

    private func startReading() {
        guard observer.authorizationStatus() == .reading else {
            observer.stop()
            access = .needsPermission
            statusMessage = "Izin Accessibility belum diberikan."
            return
        }

        guard !sources.isEmpty else {
            observer.stop()
            access = .unavailable
            statusMessage = "Pilih minimal satu aplikasi sumber."
            return
        }

        observer.start(sources: sources)
        if observer.authorizationStatus() == .reading {
            access = .reading
            statusMessage = nil
        }
    }

    private func refreshAccess() {
        guard featureEnabled, !paused else { return }

        if observer.authorizationStatus() == .reading {
            if access != .reading { startReading() }
        } else {
            observer.stop()
            access = .needsPermission
            statusMessage = "Izin Accessibility belum diberikan atau dicabut."
        }
    }

    private func apply(_ status: InboxObserverStatus) {
        guard featureEnabled else { return }

        switch status {
        case .reading:
            access = paused ? .paused : .reading
            statusMessage = nil
        case .permissionRequired:
            observer.stop()
            access = .needsPermission
            statusMessage = "Izin Accessibility belum diberikan atau dicabut."
        case .stopped:
            break
        }
    }

    private func accept(_ reading: InboxBannerReading, isSimulation: Bool = false) {
        if !isSimulation {
            guard featureEnabled, !paused,
                  reading.source.isExperimentalSource,
                  sources.contains(reading.source)
            else { return }
        }

        let normalized = InboxBannerReading(
            source: reading.source,
            sender: cleaned(reading.sender),
            title: cleaned(reading.title),
            body: cleaned(reading.body)
        )
        let timestamp = now()

        if !isSimulation {
            recent = recent.filter { timestamp.timeIntervalSince($0.value) < InboxLimits.duplicateWindow }
            if recent[normalized.fingerprint] != nil { return }
            recent[normalized.fingerprint] = timestamp
        }

        items.insert(
            InboxItem(
                id: UUID(),
                source: normalized.source,
                sender: normalized.sender,
                title: normalized.title,
                body: normalized.body,
                receivedAt: timestamp,
                isRead: false
            ),
            at: 0
        )
        if items.count > InboxLimits.capacity {
            items.removeLast(items.count - InboxLimits.capacity)
        }
    }

    private func cleaned(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(InboxLimits.maxTextLength))
    }
}
