import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

/// Experimental: reads only visible Notification Center banner text through Accessibility.
/// No screenshots, databases, or hidden previews are accessed.
@MainActor
final class AccessibilityBannerObserver: InboxObserving {
    var onReading: (@MainActor (InboxBannerReading) -> Void)?
    var onStatus: (@MainActor (InboxObserverStatus) -> Void)?

    private static let notificationCenterBundleIdentifier = "com.apple.notificationcenterui"
    private let queue = DispatchQueue(label: "com.mujabaralno.sela.inbox.accessibility", qos: .utility)
    private var timer: Timer?
    private var sources: Set<InboxSource> = []
    private var lastFingerprints: Set<String> = []
    private var scanning = false
    private var generation = 0

    deinit {
        timer?.invalidate()
    }

    func authorizationStatus() -> InboxAccess {
        AXIsProcessTrusted() ? .reading : .needsPermission
    }

    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    func start(sources: Set<InboxSource>) {
        self.sources = sources

        guard AXIsProcessTrusted() else {
            onStatus?(.permissionRequired)
            return
        }
        guard timer == nil else { return }

        generation += 1
        lastFingerprints = []
        scanning = false

        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.scan() }
        }
        timer.tolerance = 0.2
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer

        onStatus?(.reading)
        scan()
    }

    func stop() {
        generation += 1
        timer?.invalidate()
        timer = nil
        lastFingerprints = []
        scanning = false
    }

    private func scan() {
        guard timer != nil else { return }
        guard AXIsProcessTrusted() else {
            stop()
            onStatus?(.permissionRequired)
            return
        }
        guard !Self.isScreenLocked() else { return }
        guard !scanning else { return }

        guard let pid = NSRunningApplication
            .runningApplications(withBundleIdentifier: Self.notificationCenterBundleIdentifier)
            .first?
            .processIdentifier
        else { return }

        scanning = true
        let sources = self.sources
        let generation = self.generation

        queue.async { [weak self] in
            let readings = Self.readBanners(pid: pid, sources: sources)
            Task { @MainActor in
                guard let self, self.generation == generation, self.timer != nil else { return }
                self.scanning = false
                self.deliver(readings)
            }
        }
    }

    private func deliver(_ readings: [InboxBannerReading]) {
        let current = Set(readings.map(\.fingerprint))
        for reading in readings where !lastFingerprints.contains(reading.fingerprint) {
            onReading?(reading)
        }
        lastFingerprints = current
        if !readings.isEmpty { onStatus?(.reading) }
    }

    private nonisolated static func readBanners(pid: pid_t, sources: Set<InboxSource>) -> [InboxBannerReading] {
        let app = AXUIElementCreateApplication(pid)
        var readings: [InboxBannerReading] = []
        var seen = Set<String>()

        for window in elements(app, kAXWindowsAttribute) where isBannerWindow(window) {
            var values: [String] = []
            collectStrings(window, depth: 0, into: &values)

            guard let source = source(in: values, selected: sources) else { continue }
            let content = contentStrings(values)
            let reading = InboxBannerReading(
                source: source,
                sender: nil,
                title: content.first,
                body: content.dropFirst().joined(separator: " ")
            )

            if seen.insert(reading.fingerprint).inserted {
                readings.append(reading)
            }
        }
        return readings
    }

    private nonisolated static func isScreenLocked() -> Bool {
        guard let session = CGSessionCopyCurrentDictionary() as? [String: Any] else { return false }
        return session["CGSSessionScreenIsLocked"] as? Bool == true
    }

    private nonisolated static func isBannerWindow(_ window: AXUIElement) -> Bool {
        let subrole = (string(window, kAXSubroleAttribute) ?? "").lowercased()
        let role = (string(window, kAXRoleDescriptionAttribute) ?? "").lowercased()
        let marker = "\(subrole) \(role)"
        guard marker.contains("banner") || marker.contains("alert") else {
            return false
        }

        if let size = size(window) {
            guard size.width > 120, size.width <= 900, size.height <= 500 else { return false }
        }
        return true
    }

    private nonisolated static func source(in values: [String], selected: Set<InboxSource>) -> InboxSource? {
        for value in values {
            if let source = InboxSource.match(value), selected.contains(source) {
                return source
            }
        }
        return nil
    }

    private nonisolated static func contentStrings(_ values: [String]) -> [String] {
        var result: [String] = []
        var seen = Set<String>()

        for value in values {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, trimmed.count <= 600 else { continue }
            guard InboxSource.match(trimmed) == nil, !isTimeOrAction(trimmed.lowercased()) else { continue }

            if seen.insert(trimmed.lowercased()).inserted {
                result.append(String(trimmed.prefix(InboxLimits.maxTextLength)))
            }
        }
        return result
    }

    private nonisolated static func isTimeOrAction(_ value: String) -> Bool {
        let exact: Set<String> = [
            "now", "sekarang", "baru saja", "just now",
            "reply", "balas", "close", "tutup", "options", "opsi",
            "show", "tampilkan", "clear", "hapus", "mark as read", "tandai dibaca",
            "notification", "notifikasi",
        ]
        if exact.contains(value) { return true }
        if value.range(of: #"^\d{1,2}[:.]\d{2}(\s?(am|pm))?$"#, options: .regularExpression) != nil { return true }
        if value.range(of: #"^\d+\s?(m|min|menit|h|jam)\s+(yang\s+)?(lalu|ago)$"#, options: .regularExpression) != nil { return true }
        return false
    }

    private nonisolated static func collectStrings(_ element: AXUIElement, depth: Int, into values: inout [String]) {
        guard depth < 8, values.count < 60 else { return }

        for attribute in [kAXTitleAttribute, kAXValueAttribute, kAXDescriptionAttribute] {
            if let value = string(element, attribute) { values.append(value) }
        }
        for child in elements(element, kAXChildrenAttribute) {
            collectStrings(child, depth: depth + 1, into: &values)
        }
    }

    private nonisolated static func value(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return nil
        }
        return value
    }

    private nonisolated static func string(_ element: AXUIElement, _ attribute: String) -> String? {
        value(element, attribute) as? String
    }

    private nonisolated static func elements(_ element: AXUIElement, _ attribute: String) -> [AXUIElement] {
        value(element, attribute) as? [AXUIElement] ?? []
    }

    private nonisolated static func size(_ element: AXUIElement) -> CGSize? {
        guard let raw = value(element, kAXSizeAttribute),
              CFGetTypeID(raw) == AXValueGetTypeID()
        else { return nil }

        var size = CGSize.zero
        guard AXValueGetValue(raw as! AXValue, .cgSize, &size) else { return nil }
        return size
    }
}
