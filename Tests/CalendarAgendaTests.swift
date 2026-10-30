import Combine
import Foundation

private struct TestError: Error {}

private actor FakeCalendarProvider: CalendarProviding {
    nonisolated let storeChanged = Empty<Void, Never>().eraseToAnyPublisher()

    private var status: CalendarAccess
    private var storedEvents: [CalendarEvent]
    private var failure: Error?
    private(set) var requestCount = 0

    init(status: CalendarAccess, events: [CalendarEvent] = []) {
        self.status = status
        self.storedEvents = events
    }

    func setStatus(_ status: CalendarAccess) { self.status = status }
    func setEvents(_ events: [CalendarEvent]) { storedEvents = events }
    func setFailure(_ error: Error?) { failure = error }
    func requested() -> Int { requestCount }

    func authorizationStatus() async -> CalendarAccess { status }

    func requestAccess() async -> CalendarAccess {
        requestCount += 1
        status = .authorized
        return status
    }

    func events(from start: Date, to end: Date) async throws -> [CalendarEvent] {
        if let failure { throw failure }
        return storedEvents
    }
}

private func makeEvent(
    _ id: String,
    title: String,
    start: Date,
    end: Date,
    allDay: Bool = false,
    cancelled: Bool = false,
    declined: Bool = false,
    meeting: URL? = nil,
    link: URL? = nil
) -> CalendarEvent {
    CalendarEvent(
        id: id,
        title: title,
        start: start,
        end: end,
        isAllDay: allDay,
        location: nil,
        meetingURL: meeting,
        eventURL: link,
        isCancelled: cancelled,
        isDeclined: declined
    )
}

@main
@MainActor
struct CalendarAgendaTests {
    static func main() async {
        var failures = 0

        func expect(_ condition: Bool, _ message: String) {
            if !condition {
                failures += 1
                print("FAIL: \(message)")
            }
        }

        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let ongoing = makeEvent("ongoing", title: "Berlangsung", start: now.addingTimeInterval(-1_800), end: now.addingTimeInterval(1_800))
        let upcoming = makeEvent("upcoming", title: "Mendatang", start: now.addingTimeInterval(3_600), end: now.addingTimeInterval(7_200))
        let ended = makeEvent("ended", title: "Sudah lewat", start: now.addingTimeInterval(-7_200), end: now.addingTimeInterval(-3_600))
        let cancelled = makeEvent("cancelled", title: "Dibatalkan", start: now.addingTimeInterval(3_600), end: now.addingTimeInterval(7_200), cancelled: true)
        let declined = makeEvent("declined", title: "Ditolak", start: now.addingTimeInterval(3_600), end: now.addingTimeInterval(7_200), declined: true)
        let allDay = makeEvent("allDay", title: "Sepanjang hari", start: now.addingTimeInterval(-3_600), end: now.addingTimeInterval(7_200), allDay: true)
        let beyond = makeEvent("beyond", title: "Lebih dari 7 hari", start: now.addingTimeInterval(8 * 86_400), end: now.addingTimeInterval(8 * 86_400 + 3_600))

        let visible = CalendarAgenda.visibleEvents(
            from: [ended, cancelled, declined, upcoming, allDay, ongoing, beyond],
            now: now
        )
        expect(visible.map(\.id) == ["ongoing", "upcoming", "allDay"],
               "agenda mengutamakan acara berwaktu lalu sepanjang hari dan membuang acara selesai/batal/ditolak")
        expect(CalendarAgenda.kind(of: ongoing, now: now) == .ongoing, "acara yang sedang berlangsung terdeteksi")
        expect(CalendarAgenda.kind(of: upcoming, now: now) == .upcoming, "acara mendatang terdeteksi")
        expect(CalendarAgenda.kind(of: allDay, now: now) == .allDay, "acara sepanjang hari terdeteksi")

        let meet = CalendarLinkDetector.links(eventURL: URL(string: "https://meet.google.com/abc-defg-hij"), location: nil, notes: nil)
        expect(meet.meeting?.host == "meet.google.com" && meet.event == nil, "Google Meet dikenali sebagai meeting")

        let zoom = CalendarLinkDetector.links(eventURL: nil, location: "https://us02web.zoom.us/j/123456", notes: nil)
        expect(zoom.meeting?.host == "us02web.zoom.us", "Zoom dikenali sebagai meeting")

        let teams = CalendarLinkDetector.links(eventURL: nil, location: nil, notes: "Join https://teams.microsoft.com/l/meetup-join/abc")
        expect(teams.meeting?.host == "teams.microsoft.com", "Microsoft Teams dikenali sebagai meeting")

        let webex = CalendarLinkDetector.links(eventURL: URL(string: "https://company.webex.com/meet/room"), location: nil, notes: nil)
        expect(webex.meeting?.host == "company.webex.com", "Webex dikenali sebagai meeting")

        let whereby = CalendarLinkDetector.links(eventURL: URL(string: "https://whereby.com/room"), location: nil, notes: nil)
        expect(whereby.meeting?.host == "whereby.com", "Whereby dikenali sebagai meeting")

        let jitsi = CalendarLinkDetector.links(eventURL: URL(string: "https://meet.jit.si/room"), location: nil, notes: nil)
        expect(jitsi.meeting?.host == "meet.jit.si", "Jitsi dikenali sebagai meeting")

        let generic = CalendarLinkDetector.links(eventURL: URL(string: "https://example.com/acara"), location: nil, notes: nil)
        expect(generic.meeting == nil && generic.event?.host == "example.com", "tautan web biasa menjadi Open event link")

        let mixed = CalendarLinkDetector.links(
            eventURL: URL(string: "https://example.com/acara"),
            location: nil,
            notes: "Rapat di https://meet.google.com/abc"
        )
        expect(mixed.meeting?.host == "meet.google.com" && mixed.event?.host == "example.com", "meeting diutamakan atas tautan acara")

        let invalid = CalendarLinkDetector.links(eventURL: URL(string: "mailto:halo@example.com"), location: "Ruang 4", notes: "Tanpa tautan")
        expect(invalid.meeting == nil && invalid.event == nil, "tautan non-HTTP tidak dianggap dapat dibuka")

        let authorizedProvider = FakeCalendarProvider(
            status: .authorized,
            events: [ongoing, upcoming, ended, cancelled, declined, allDay]
        )
        let authorized = CalendarService(provider: authorizedProvider, now: { now })
        await authorized.refresh()
        expect(authorized.access == .authorized, "status akses terbaca")
        expect(authorized.hasLoaded, "agenda berhasil dimuat")
        expect(authorized.events.map(\.id) == ["ongoing", "upcoming", "allDay"], "service memakai filter agenda yang sama")
        expect(authorized.errorMessage == nil && !authorized.isLoading, "pemuatan selesai tanpa error")

        let permissionProvider = FakeCalendarProvider(status: .needsPermission)
        let permission = CalendarService(provider: permissionProvider, now: { now })
        await permission.refresh()
        expect(permission.access == .needsPermission, "status belum diizinkan terdeteksi")
        expect(permission.events.isEmpty && !permission.hasLoaded, "refresh tanpa izin tidak memuat agenda")

        let requestProvider = FakeCalendarProvider(status: .needsPermission, events: [upcoming])
        let requested = CalendarService(provider: requestProvider, now: { now })
        await requested.requestAccess()
        expect(await requestProvider.requested() == 1, "permintaan izin hanya terjadi lewat requestAccess")
        expect(requested.access == .authorized, "izin yang diberikan memperbarui status")
        expect(requested.events.map(\.id) == ["upcoming"], "agenda dimuat setelah izin diberikan")

        let revokedProvider = FakeCalendarProvider(status: .authorized, events: [upcoming])
        let revoked = CalendarService(provider: revokedProvider, now: { now })
        await revoked.refresh()
        expect(revoked.events.count == 1, "agenda awal tersedia")
        await revokedProvider.setStatus(.denied)
        await revoked.refresh()
        expect(revoked.access == .denied, "pencabutan izin terdeteksi")
        expect(revoked.events.isEmpty && !revoked.hasLoaded, "agenda dibersihkan saat izin dicabut")

        let failingProvider = FakeCalendarProvider(status: .authorized)
        await failingProvider.setFailure(TestError())
        let failing = CalendarService(provider: failingProvider, now: { now })
        await failing.refresh()
        expect(failing.errorMessage != nil, "kegagalan pembaruan memberi pesan")
        expect(!failing.hasLoaded && !failing.isLoading, "kegagalan tidak meninggalkan status memuat")

        let emptyProvider = FakeCalendarProvider(status: .authorized)
        let empty = CalendarService(provider: emptyProvider, now: { now })
        await empty.refresh()
        expect(empty.hasLoaded && empty.events.isEmpty && empty.errorMessage == nil, "kalender kosong tetap dianggap berhasil dibaca")

        if failures == 0 {
            print("Calendar agenda tests passed.")
        } else {
            print("\(failures) calendar agenda test(s) failed.")
        }
        exit(failures == 0 ? 0 : 1)
    }
}
