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
