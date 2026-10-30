# Sela UI redesign

## Audit sebelum perubahan

Checkout ini memiliki Timer/Pomodoro, Music, Battery dan pet Pomodoro. Tidak ada
implementasi Shelf/Clipboard/Calendar/Inbox pada checkout ini. Tidak ada tab palsu
yang ditambahkan atau fitur yang dihapus.

NotchController mengoordinasikan DynamicNotchKit, hover dan pemilihan tab.
ContentView adalah jendela pendamping. Panel fitur SwiftUI mengamati model
terpisah. TimerModel, BatteryModel, BatteryAlertPolicy, MusicService, provider
MediaRemote dan penyimpanan tidak diubah.

Masalah awal: lebar panel 272–300pt, teks caption2 terlalu kecil, kontrol sesi
kecil, material sistem berubah mengikuti wallpaper, hirarki datar, tab tidak
menunjukkan pilihan di notch, dan jendela pendamping menampilkan status debugging.

## Sistem baru

- Sela/Design/SelaTheme.swift: black #000000, warm #111110, ivory #F4F1E9,
  aksen status lembut, skala tipografi sistem dan komponen tombol/ring/bar.
- Sela/Design/NotchChrome.swift: navigasi, prioritas dan sayap compact.
- Sela/Design/SelaMotion.swift: masuk konten bertahap, marquee, alarm pulse.
- Sela/Design/FloatingSelaPanel.swift: panel nonactivating hitam untuk layar tanpa
  notch. Frame panel sama dengan area visual, bukan area transparan layar.
- Konten expanded 408pt, biasanya 177–188pt tinggi, radius 24pt; hardware chrome
  DynamicNotchKit tetap memberi bahu cekung dan ruang kamera. Mode tanpa notch
  menggunakan pill hitam sendiri, tanpa material popover.
- Target navigasi minimum 28pt, tombol utama minimum 36pt; SF Symbols dan sistem
  font saja. Teks sekunder 62% ivory / 85% saat Increase Contrast.
- Spring response 0.35 / damping 0.8; dwell 120ms, grace 500ms. Reduce Motion
  menonaktifkan gerakan shell, marquee, equalizer dan pulse; konten cukup fade.
- Prioritas presentasi: alarm timer selesai > timer berjalan/dijeda > sesi Music
  (paused memakai equalizer statis) > alert baterai/low battery > idle tersembunyi.
- Low battery compact tetap tersedia selama kondisi rendah dan alerts aktif.
  Durasi alert charger mengikuti model yang sudah ada (4 detik), tanpa mengubah
  kebijakan layanan. Battery Alerts tetap mengatur notifikasi yang sama.
- Pet Pomodoro tetap ada di Timer. Marker dua titik menyatakan mode Fokus/Rest,
  bukan riwayat sesi yang belum disimpan aplikasi.

## Data yang sengaja tidak direkayasa

Model musik belum mengekspos durasi/elapsed ke presentasi: tidak ada progress atau
waktu palsu. Model baterai belum menyediakan estimasi waktu atau ambang editable:
UI menampilkan ambang tetap 20%, tanpa kontrol yang seolah menyimpannya. Sesi
selesai menyediakan aksi mulai sesi berikut melalui metode timer yang sudah ada.

## Verifikasi

Design tokens berhasil build. Setelah regenerasi project dan koreksi MainActor,
shell dan ketiga fitur berhasil build bersama. Fase polish/fallback juga berhasil
build dengan scheme Sela, signing dimatikan. Project tetap macOS 13. Tidak ada
penambahan dependency atau perubahan identitas teknis.

MusicService sintetis, pengaman transport sintetis, dan BatteryAlertPolicy lulus.
Screenshot UI langsung diperiksa di percakapan: Timer pada jendela pendamping,
serta cover dan equalizer compact di atas wallpaper terang. Tidak ada metadata
media pribadi yang disimpan ke repo sebagai screenshot/fixture. Tidak ada
perintah transport media yang dikirim untuk pengujian redesain.

Preview sintetis tersedia untuk idle, compact, expanded, timer Fokus/Rest/alarm,
Music playing/paused/empty, baterai charging/low/unavailable. Preview tidak
menginisialisasi layanan baterai atau koneksi musik.

Masih perlu uji nyata: monitor eksternal/tanpa notch, pindah antar-display,
fullscreen/Spaces, perpindahan kursor kamera→panel, VoiceOver, pengaturan Reduce
Motion/Increase Contrast sistem, dan semua preview di canvas Xcode. Build preview
bukan bukti semua state sudah dirender di canvas. Playback lintas aplikasi tetap
mengikuti batas pengujian sebelumnya; tidak diuji ulang oleh redesain ini.


## Refinement · 29 October 2026

Presentation-only refinement of the existing Sela target. Audit found shifting tab
widths, heavy secondary buttons, competing control surfaces and inconsistent
feature hierarchy. The existing SwiftUI faces remain connected to the same
callbacks; timer, battery, MediaRemote, Shelf storage, hover tracking, activity
priority and drag/drop services are unchanged.

- Stable four-tab navigation always exposes both SF Symbol and label. Existing
  indices are preserved. No unimplemented features are added.
- Pure black notch, warm ivory text, near-black controls, system typography.
  Secondary controls use quiet backgrounds; primary actions retain clear fill.
- Expanded content is 408 × 216 pt for Timer, Music and Battery. The 32 pt tab
  bar, 16 pt spacing and 136 pt activity region share a common rhythm.
- Timer uses a 116 pt ring, tabular time and grouped session choices. Existing
  companion, start/pause/reset and end-of-session actions remain available.
- Music uses 84 pt artwork, a 44 pt primary transport button, quiet adjacent
  controls and a separated source/status row. Unsupported controls remain
  disabled using the same capabilities and session token.
- Battery uses a larger tabular percentage, thin charge track and a compact
  settings row. The existing alerts binding and fixed threshold are preserved.
- Shelf retains 56 pt full-width rows, a 28 pt remove target and at most three
  visible rows before scrolling. Empty state is shorter; height follows content.
- Companion window separates the black notch preview from its warm surface.
- Reduce Motion retains fade-only interaction feedback. Increase Contrast raises
  secondary/tab contrast and adds control outlines. Existing VoiceOver labels
  are retained; transport labels are localized.

Verification: Xcode Sela build passed. Synthetic Music service/transport guard,
battery policy, Shelf service and AppKit destination tests passed. The AppKit
Shelf test requires pasteboard access outside the sandbox and emits the existing
sandbox-extension diagnostic for synthetic file URLs; assertions pass. Four
feature faces rendered with synthetic data and were visually inspected. SwiftUI
previews cover idle/compact/expanded, timer focus/rest/paused/alarm, music
playing/paused/empty/unavailable/limited controls, and battery charging/low/unknown.
No private playback commands were sent. Running Sela was not restarted, preserving
its in-memory Shelf. Real notch hover, Finder dragging, fullscreen/multi-display,
VoiceOver and OS accessibility preference changes still need manual verification.

## Calendar · 30 October 2026

The Calendar feature is now implemented, so the previously absent tab is added as
the fifth navigation item (Timer, Baterai, Music, Calendar, Shelf). Existing Shelf
indices move with it; drag-to-Shelf still selects the Shelf tab without changing the
user's manual tab choice.

- EventKit access is read-only. `CalendarService` checks authorization status without
  prompting; `requestFullAccessToEvents` (macOS 14+) or `requestAccess(to: .event)`
  (macOS 13) runs only from the Allow Calendar Access button.
- EventKit queries run in `EventKitCalendarProvider` actor. Only value snapshots leave
  the actor; notes are parsed for meeting links and never retained.
- The panel shows seven days of ongoing/upcoming events, timed before all-day, with
  clear Berlangsung/Mendatang/Sepanjang hari labels, location, and Join meeting or
  Open event link buttons. Denied, restricted, empty, loading, and failed states are
  explicit; Refresh remains available.
- Agenda refreshes on tab open, EventKit changes, app activation, every 60 seconds,
  and manual refresh. Stale query results are discarded and revoked access clears the
  in-memory agenda.
- Calendar content uses the existing 408 pt surface, 12 pt control radius, typography,
  and quiet secondary controls. Its height is 264 pt to fit the scrolling agenda.
- Synthetic provider and agenda/link tests cover the feature. Real permission dialogs
  and personal calendar data were not used and remain manual verification.

## Inbox · 30 October 2026

Inbox is added as the sixth navigation item (Timer, Baterai, Music, Calendar, Shelf,
Inbox). It is experimental and disabled by default.

- Live banner capture is opt-in. Enabling the feature does not prompt for
  Accessibility; the explicit Allow button does. The observer reads only Notification
  Center banner/alert windows and copies exposed text into memory.
- Source selection, pause/resume, disable, clear history, an open-source action, and
  the existing simulation/`notchapp://notify` path are available. No source is
  selected by default; enabling without a source asks the user to choose one.
  Hidden previews and restricted notification states are not forced open.
- Inbox content is 400 pt to fit controls, permission state, and a scrolling list.
  New unread items add a compact bell/count indicator after battery and before Shelf;
  they do not change the selected tab, timer, or drag/drop state.
- Real WhatsApp, Telegram, and Messages banner capture has not been verified. The
  feature remains marked experimental; the per-app result table and manual protocol
  live in `Tests/InboxValidation.md`.
