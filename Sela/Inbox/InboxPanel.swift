import SwiftUI

enum InboxLayout {
    static let contentHeight: CGFloat = 400
}

struct InboxPanel: View {
    @ObservedObject var inbox: InboxService

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            experimentalControls
            if inbox.statusMessage != nil || inbox.featureEnabled {
                status
            }
            sources
            Divider().overlay(SelaTheme.raised)
            notifications
            footer
        }
        .foregroundStyle(SelaTheme.ivory)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("Inbox").font(.system(size: 13, weight: .medium))
            Text("Eksperimental")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(SelaTheme.amber)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(SelaTheme.raised, in: Capsule())
            Spacer(minLength: 4)
            if inbox.featureEnabled {
                SelaIconButton(symbol: inbox.paused ? "play.fill" : "pause.fill",
                               label: inbox.paused ? "Lanjutkan penerimaan" : "Jeda penerimaan") {
                    inbox.setPaused(!inbox.paused)
                }
            }
            SelaIconButton(symbol: "plus", label: "Tambah notifikasi uji") { inbox.addSimulation() }
            SelaIconButton(symbol: "trash", label: "Hapus riwayat Inbox") { inbox.clear() }
                .disabled(inbox.items.isEmpty)
        }
    }

    private var experimentalControls: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle("Baca banner aplikasi lain", isOn: Binding(
                get: { inbox.featureEnabled },
                set: { inbox.setEnabled($0) }
            ))
            .toggleStyle(.switch).controlSize(.mini)
            .font(.system(size: 11))

            Text("Opsional dan nonaktif secara default. Sela menyalin hanya teks banner yang terlihat lewat izin Accessibility; pratinjau tersembunyi tidak dibaca dan isi hanya disimpan di memori.")
                .font(.system(size: 10)).selaSecondary()
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var status: some View {
        if inbox.featureEnabled, inbox.access == .needsPermission {
            VStack(alignment: .leading, spacing: 6) {
                Text("Akses Accessibility diperlukan untuk membaca banner. Tanpa izin ini Sela tidak dapat menyalin notifikasi aplikasi lain.")
                    .font(.system(size: 10)).selaSecondary()
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    Button("Izinkan akses Accessibility") { inbox.requestAccessibility() }
                        .buttonStyle(SelaButtonStyle(prominent: true))
                    Button("Buka Pengaturan") { inbox.openAccessibilitySettings() }
                        .buttonStyle(SelaButtonStyle())
                }
            }
        } else {
            HStack(spacing: 6) {
                Circle()
                    .fill(inbox.access == .reading ? SelaTheme.green : SelaTheme.amber)
                    .frame(width: 5, height: 5)
                Text(statusText)
                    .font(.system(size: 10)).selaSecondary()
                    .lineLimit(2)
                Spacer(minLength: 0)
            }
        }
    }

    private var statusText: String {
        if let message = inbox.statusMessage { return message }
        switch inbox.access {
        case .disabled: return "Pembacaan banner nonaktif."
        case .needsPermission: return "Izin Accessibility belum diberikan."
        case .reading: return "Membaca banner terlihat. Hasil per aplikasi belum terverifikasi."
        case .paused: return "Penerimaan dijeda."
        case .unavailable: return "Sumber belum siap."
        }
    }

    private var sources: some View {
        HStack(spacing: 6) {
            ForEach(InboxSource.selectable) { source in
                let selected = inbox.sources.contains(source)
                Button { inbox.toggleSource(source) } label: {
                    HStack(spacing: 4) {
                        Image(systemName: source.symbolName)
                        Text(source.displayName)
                    }
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 8).frame(minHeight: 24)
                    .background(selected ? SelaTheme.raised : .clear, in: Capsule())
                    .overlay(Capsule().strokeBorder(selected ? SelaTheme.ivory.opacity(0.22) : SelaTheme.ivory.opacity(0.08)))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
                .help(selected ? "Berhenti membaca \(source.displayName)" : "Baca \(source.displayName)")
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var notifications: some View {
        if inbox.items.isEmpty {
            VStack(spacing: 5) {
                Image(systemName: "bell.slash").font(.system(size: 18, weight: .light)).accessibilityHidden(true)
                Text("Belum ada notifikasi").font(.system(size: 12, weight: .medium))
                Text("Aktifkan fitur lalu kirim pesan uji, atau buka notchapp://notify untuk mencoba tampilan Inbox.")
                    .font(.system(size: 10)).selaSecondary()
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(inbox.items) { item in
                        InboxRow(item: item, open: { inbox.open(item.source) })
                    }
                }
                .padding(.bottom, 2)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Text("\(inbox.unreadCount) belum dibaca · isi hanya di memori")
                .font(.system(size: 9)).selaSecondary()
            Spacer(minLength: 0)
            Text("Bersihkan tidak menghapus notifikasi sistem")
                .font(.system(size: 9)).selaSecondary()
                .lineLimit(1)
        }
    }
}

private struct InboxRow: View {
    let item: InboxItem
    let open: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: item.source.symbolName)
                .font(.system(size: 12, weight: .medium))
                .frame(width: 20)
                .foregroundStyle(item.source == .simulation ? SelaTheme.amber : SelaTheme.ivory)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(item.source.displayName).font(.system(size: 9, weight: .medium)).selaSecondary()
                    if !item.isRead {
                        Circle().fill(SelaTheme.amber).frame(width: 4, height: 4)
                            .accessibilityLabel("Belum dibaca")
                    }
                    Spacer(minLength: 4)
                    Text(timeText).font(.system(size: 9)).selaSecondary()
                }
                Text(item.headline).font(.system(size: 12, weight: .medium)).lineLimit(1)
                if let preview = item.preview {
                    Text(preview).font(.system(size: 10)).selaSecondary().lineLimit(2)
                } else {
                    Text("Pratinjau tidak tersedia").font(.system(size: 10)).selaSecondary()
                }
            }

            if item.source.bundleIdentifier != nil {
                Button("Buka", action: open)
                    .buttonStyle(.plain)
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 8).frame(minHeight: 24)
                    .background(SelaTheme.raised, in: RoundedRectangle(cornerRadius: 7))
                    .accessibilityLabel("Buka \(item.source.displayName)")
                    .help("Buka \(item.source.displayName); tidak membuka percakapan tertentu")
            }
        }
        .padding(8)
        .background(SelaTheme.surface, in: RoundedRectangle(cornerRadius: 10))
    }

    private var timeText: String {
        let seconds = max(0, Date().timeIntervalSince(item.receivedAt))
        if seconds < 60 { return "Baru saja" }
        if seconds < 3_600 { return "\(Int(seconds / 60)) mnt" }
        return item.receivedAt.formatted(date: .omitted, time: .shortened)
    }
}

#Preview("Inbox · Off") {
    InboxPanel(inbox: InboxService(observer: PreviewInboxObserver()))
        .padding(16).frame(width: 408).selaSurface()
}

@MainActor
private final class PreviewInboxObserver: InboxObserving {
    var onReading: (@MainActor (InboxBannerReading) -> Void)?
    var onStatus: (@MainActor (InboxObserverStatus) -> Void)?
    func authorizationStatus() -> InboxAccess { .needsPermission }
    func requestAccessibility() {}
    func start(sources: Set<InboxSource>) {}
    func stop() {}
}
