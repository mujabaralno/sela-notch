import AppKit
import Combine
import Foundation

protocol CalendarProviding: AnyObject {
    var storeChanged: AnyPublisher<Void, Never> { get }
    func authorizationStatus() async -> CalendarAccess
    func requestAccess() async -> CalendarAccess
    func events(from start: Date, to end: Date) async throws -> [CalendarEvent]
}

/// Agenda stays in memory. Reads are value snapshots; no notes or write access.
@MainActor
final class CalendarService: ObservableObject {
    @Published private(set) var access: CalendarAccess = .unknown
    @Published private(set) var events: [CalendarEvent] = []
    @Published private(set) var isLoading = false
    @Published private(set) var hasLoaded = false
    @Published private(set) var errorMessage: String?

    private let provider: CalendarProviding
    private let now: () -> Date
    private var generation = 0
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var started = false

    init(provider: CalendarProviding, now: @escaping () -> Date = Date.init) {
        self.provider = provider
        self.now = now
    }

    deinit {
        timer?.invalidate()
    }

    func start() {
        guard !started else { return }
        started = true

        provider.storeChanged
            .sink { [weak self] in
                Task { @MainActor in await self?.refresh() }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                Task { @MainActor in await self?.refresh() }
            }
            .store(in: &cancellables)

        let timer = Timer(timeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
        timer.tolerance = 10
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer

        Task { await self.checkAuthorization() }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        cancellables.removeAll()
        started = false
        generation += 1
    }

    func checkAuthorization() async {
        applyAuthorization(await provider.authorizationStatus())
    }

    func requestAccess() async {
        isLoading = true
        let status = await provider.requestAccess()
        applyAuthorization(status)

        guard status == .authorized else {
            isLoading = false
            return
        }
        await load()
    }

    func refresh() async {
        let status = await provider.authorizationStatus()
        applyAuthorization(status)

        guard status == .authorized else { return }
        await load()
    }

    private func applyAuthorization(_ status: CalendarAccess) {
        access = status
        guard status != .authorized else { return }

        generation += 1
        events = []
        hasLoaded = false
        isLoading = false
        errorMessage = nil
    }

    private func load() async {
        generation += 1
        let token = generation
        let reference = now()
        isLoading = true
        errorMessage = nil

        do {
            let fetched = try await provider.events(
                from: CalendarAgenda.fetchStart(from: reference),
                to: CalendarAgenda.end(from: reference)
            )
            guard token == generation else { return }

            let status = await provider.authorizationStatus()
            guard token == generation else { return }
            guard status == .authorized else {
                applyAuthorization(status)
                return
            }

            events = CalendarAgenda.visibleEvents(from: fetched, now: reference)
            hasLoaded = true
            isLoading = false
        } catch {
            guard token == generation else { return }

            let status = await provider.authorizationStatus()
            guard token == generation else { return }
            guard status == .authorized else {
                applyAuthorization(status)
                return
            }

            isLoading = false
            errorMessage = "Agenda tidak dapat dimuat. Coba lagi."
        }
    }
}
