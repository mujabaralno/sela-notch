import AppKit
import Combine
import SwiftUI

enum CalendarLayout {
    static let contentHeight: CGFloat = 264
}

struct CalendarPanel: View {
    @ObservedObject var calendar: CalendarService

    var body: some View {
        Group {
            switch calendar.access {
            case .unknown:
                loadingState("Memeriksa akses kalender…")
            case .needsPermission:
                permission
            case .denied, .restricted:
                denied
            case .authorized:
                agenda
            }
        }
        .foregroundStyle(SelaTheme.ivory)
    }

    private var permission: some View {
        VStack(spacing: 10) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 24, weight: .light))
                .accessibilityHidden(true)
            Text("Agenda tujuh hari").font(.system(size: 15, weight: .medium))
            Text("Sela membaca kalender yang sudah ada di Mac untuk menampilkan acara dan tautan meeting. Sela tidak membuat, mengubah, atau menghapus acara.")
                .font(.system(size: 11)).selaSecondary()
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            Button("Allow Calendar Access") {
                Task { await calendar.requestAccess() }
            }
            .buttonStyle(SelaButtonStyle(prominent: true))
            .disabled(calendar.isLoading)
        }
        .frame(maxWidth: .infinity, minHeight: 180)
    }

    private var denied: some View {
        VStack(spacing: 10) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(SelaTheme.amber)
                .accessibilityHidden(true)
            Text(calendar.access == .restricted ? "Akses kalender dibatasi" : "Akses kalender dinonaktifkan")
                .font(.system(size: 15, weight: .medium))
            Text(calendar.access == .restricted
                 ? "Akses kalender dibatasi oleh pengaturan perangkat atau administrator. Agenda tidak dapat ditampilkan."
                 : "Izinkan Sela membaca kalender di System Settings › Privacy & Security › Calendars, lalu periksa lagi.")
                .font(.system(size: 11)).selaSecondary()
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                Button("Buka Pengaturan") { openCalendarSettings() }
                    .buttonStyle(SelaButtonStyle(prominent: true))
                Button("Periksa lagi") {
                    Task { await calendar.refresh() }
                }
                .buttonStyle(SelaButtonStyle())
                .disabled(calendar.isLoading)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 180)
    }

    private var agenda: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Agenda · 7 hari").font(.system(size: 13, weight: .medium))
                Spacer(minLength: 8)
                SelaIconButton(symbol: "arrow.clockwise", label: "Perbarui agenda") {
                    Task { await calendar.refresh() }
                }
                .disabled(calendar.isLoading)
            }

            if let message = calendar.errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(SelaTheme.amber)
                        .accessibilityHidden(true)
                    Text(message).font(.system(size: 11)).selaSecondary()
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 8)
                    Button("Coba lagi") {
                        Task { await calendar.refresh() }
                    }
                    .buttonStyle(SelaButtonStyle())
                    .disabled(calendar.isLoading)
                }
                .padding(10)
                .background(SelaTheme.surface, in: RoundedRectangle(cornerRadius: 12))
            }

            if !calendar.hasLoaded {
                if calendar.errorMessage == nil {
                    loadingState(calendar.isLoading ? "Memuat agenda…" : "Menyiapkan agenda…")
                }
            } else if calendar.events.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.system(size: 22, weight: .light))
                        .accessibilityHidden(true)
                    Text("Tidak ada acara dalam 7 hari")
                        .font(.system(size: 13, weight: .medium))
                    Text("Kalender berhasil dibaca.")
                        .font(.system(size: 11)).selaSecondary()
                }
                .frame(maxWidth: .infinity, minHeight: 140)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(calendar.events) { event in
                            CalendarEventRow(event: event, now: Date())
                        }
                    }
                    .padding(.bottom, 2)
                }
                .scrollIndicators(.hidden)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func loadingState(_ text: String) -> some View {
        VStack(spacing: 8) {
            ProgressView().controlSize(.small).tint(SelaTheme.ivory)
            Text(text).font(.system(size: 11)).selaSecondary()
        }
        .frame(maxWidth: .infinity, minHeight: 140)
    }

    private func openCalendarSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") else { return }
        NSWorkspace.shared.open(url)
    }
}

struct CalendarEventRow: View {
    let event: CalendarEvent
    let now: Date

    private var kind: CalendarEventKind { CalendarAgenda.kind(of: event, now: now) }
    private var link: URL? { event.meetingURL ?? event.eventURL }
    private var isMeeting: Bool { event.meetingURL != nil }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(kindLabel)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(kindTint)
                Text(dayText)
                    .font(.system(size: 10)).selaSecondary()
                    .lineLimit(1)
            }
            .frame(width: 72, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                Text(event.title.isEmpty ? "Acara tanpa judul" : event.title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(2)
                if !timeText.isEmpty {
                    Text(timeText)
                        .font(.system(size: 11)).selaSecondary()
                        .lineLimit(1)
                }
                if let location = event.location, !location.isEmpty {
                    Label(location, systemImage: "mappin.and.ellipse")
                        .font(.system(size: 10)).selaSecondary()
                        .lineLimit(1)
                }
                if let link {
                    Button {
                        NSWorkspace.shared.open(link)
                    } label: {
                        Label(isMeeting ? "Join meeting" : "Open event link",
                              systemImage: isMeeting ? "video.fill" : "arrow.up.right.square")
                            .font(.system(size: 11, weight: .medium))
                            .padding(.horizontal, 10)
                            .frame(minHeight: 28)
                            .background(SelaTheme.raised, in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isMeeting ? "Join meeting \(event.title)" : "Buka tautan acara \(event.title)")
                    .help(link.absoluteString)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .background(SelaTheme.surface, in: RoundedRectangle(cornerRadius: 12))
    }

    private var kindLabel: String {
        switch kind {
        case .ongoing: "Berlangsung"
        case .upcoming: "Mendatang"
        case .allDay: "Sepanjang hari"
        }
    }

    private var kindTint: Color {
        switch kind {
        case .ongoing: SelaTheme.green
        case .upcoming: SelaTheme.ivory.opacity(0.62)
        case .allDay: SelaTheme.rest
        }
    }

    private var dayText: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(event.start) { return "Hari ini" }
        if calendar.isDateInTomorrow(event.start) { return "Besok" }
        return event.start.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }

    private var timeText: String {
        guard kind != .allDay else { return "" }

        let start = event.start.formatted(date: .omitted, time: .shortened)
        let end = event.end.formatted(date: .omitted, time: .shortened)

        if kind == .ongoing { return "Sampai \(end)" }
        if Calendar.current.isDate(event.start, inSameDayAs: event.end) {
            return "\(start)–\(end)"
        }
        return "\(start) – \(event.end.formatted(.dateTime.day().month(.abbreviated).hour().minute()))"
    }
}

#Preview("Calendar · Permission") {
    CalendarPanel(calendar: CalendarService(provider: PreviewCalendarProvider()))
        .padding(16).frame(width: 408).selaSurface()
}

private final class PreviewCalendarProvider: CalendarProviding {
    let storeChanged = Empty<Void, Never>().eraseToAnyPublisher()

    func authorizationStatus() async -> CalendarAccess { .needsPermission }
    func requestAccess() async -> CalendarAccess { .needsPermission }
    func events(from start: Date, to end: Date) async throws -> [CalendarEvent] { [] }
}
