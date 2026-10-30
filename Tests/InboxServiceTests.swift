import Foundation

@MainActor
private final class FakeInboxObserver: InboxObserving {
    var onReading: (@MainActor (InboxBannerReading) -> Void)?
    var onStatus: (@MainActor (InboxObserverStatus) -> Void)?

    var trusted: Bool
    private(set) var requested = false
    private(set) var started = false
    private(set) var startCount = 0
    private(set) var activeSources: Set<InboxSource> = []

    init(trusted: Bool = true) {
        self.trusted = trusted
    }

    func authorizationStatus() -> InboxAccess { trusted ? .reading : .needsPermission }
    func requestAccessibility() { requested = true }

    func start(sources: Set<InboxSource>) {
        started = true
        startCount += 1
        activeSources = sources
    }

    func stop() { started = false }

    func emit(_ reading: InboxBannerReading) { onReading?(reading) }
    func emit(_ status: InboxObserverStatus) { onStatus?(status) }
}

@main
@MainActor
struct InboxServiceTests {
    static func main() {
        var failures = 0

        func expect(_ condition: Bool, _ message: String) {
            if !condition {
                failures += 1
                print("FAIL: \(message)")
            }
        }

        let parsed = InboxURL.reading(from: URL(string: "notchapp://notify?sender=Tim&title=Halo&body=Pesan%20uji")!)
        expect(parsed?.source == .simulation, "URL simulasi memakai sumber simulasi")
        expect(parsed?.sender == "Tim" && parsed?.title == "Halo" && parsed?.body == "Pesan uji", "URL simulasi membaca query")
        expect(InboxURL.reading(from: URL(string: "notchapp://notify")!)?.title == "Notifikasi uji", "URL tanpa query memakai judul uji")
        expect(InboxURL.reading(from: URL(string: "https://notify")!) == nil, "skema lain diabaikan")
        expect(InboxURL.reading(from: URL(string: "notchapp://other")!) == nil, "host lain diabaikan")

        let observer = FakeInboxObserver()
        var currentTime = Date(timeIntervalSince1970: 1_800_000_000)
        let service = InboxService(observer: observer, now: { currentTime })

        observer.emit(InboxBannerReading(source: .whatsapp, sender: "A", title: "Sebelum aktif", body: nil))
        expect(service.items.isEmpty, "banner diabaikan saat fitur nonaktif")

        service.handle(url: URL(string: "notchapp://notify?title=Simulasi")!)
        expect(service.items.count == 1 && service.items[0].source == .simulation, "simulasi tetap tersedia saat fitur nonaktif")

        service.setSource(.whatsapp, enabled: true)
        service.setSource(.telegram, enabled: true)
        service.setEnabled(true)
        expect(service.featureEnabled && service.access == .reading, "fitur aktif dengan izin terbaca")
        expect(observer.started && observer.activeSources == [.whatsapp, .telegram], "observer hanya memakai sumber yang dipilih")

        observer.emit(InboxBannerReading(source: .telegram, sender: "Tim", title: "Halo", body: "Pesan uji"))
        expect(service.items.count == 2 && service.items[0].source == .telegram, "banner Telegram masuk ke Inbox")
        expect(service.unreadCount == 2, "item baru dihitung belum dibaca")

        observer.emit(InboxBannerReading(source: .telegram, sender: "Tim", title: "Halo", body: "Pesan uji"))
        expect(service.items.count == 2, "banner identik tidak diduplikasi")

        currentTime = currentTime.addingTimeInterval(31)
        observer.emit(InboxBannerReading(source: .telegram, sender: "Tim", title: "Halo", body: "Pesan uji"))
        expect(service.items.count == 3, "banner identik setelah jendela waktu dianggap baru")

        service.setSource(.telegram, enabled: false)
        observer.emit(InboxBannerReading(source: .telegram, sender: "Tim", title: "Nonaktif", body: nil))
        expect(service.items.count == 3, "sumber yang dimatikan diabaikan")
        observer.emit(InboxBannerReading(source: .whatsapp, sender: "Dina", title: "Masih aktif", body: nil))
        expect(service.items.count == 4, "sumber yang dipilih tetap dibaca")

        service.setPaused(true)
        expect(service.access == .paused && !observer.started, "jeda menghentikan observer")
        observer.emit(InboxBannerReading(source: .whatsapp, sender: "Dina", title: "Saat jeda", body: nil))
        expect(service.items.count == 4, "banner diabaikan saat dijeda")
        service.setPaused(false)
        expect(observer.started && service.access == .reading, "lanjutkan memulai observer lagi")

        service.markAllRead()
        expect(service.unreadCount == 0, "tandai dibaca membersihkan hitungan")
        service.clear()
        expect(service.items.isEmpty && service.unreadCount == 0, "hapus riwayat membersihkan Inbox")

        for _ in 0..<25 { service.addSimulation() }
        expect(service.items.count == InboxLimits.capacity, "riwayat dibatasi kapasitas")

        let deniedObserver = FakeInboxObserver(trusted: false)
        let denied = InboxService(observer: deniedObserver)
        denied.setEnabled(true)
        expect(denied.access == .needsPermission && !deniedObserver.started, "fitur aktif tanpa izin tidak membaca")
        denied.requestAccessibility()
        expect(deniedObserver.requested, "permintaan izin hanya lewat aksi eksplisit")
        expect(denied.statusMessage != nil, "status izin dijelaskan")

        deniedObserver.emit(.permissionRequired)
        expect(denied.access == .needsPermission, "pencabutan izin terdeteksi")

        let emptySourcesObserver = FakeInboxObserver()
        let emptySources = InboxService(observer: emptySourcesObserver)
        emptySources.setEnabled(true)
        expect(emptySources.access == .unavailable && !emptySourcesObserver.started, "tanpa sumber tidak memulai pembacaan")
        expect(emptySources.statusMessage != nil, "tanpa sumber memberi penjelasan")

        if failures == 0 {
            print("Inbox service tests passed.")
        } else {
            print("\(failures) inbox test(s) failed.")
        }
        exit(failures == 0 ? 0 : 1)
    }
}
