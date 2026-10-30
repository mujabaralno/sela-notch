# Sela

Aplikasi macOS untuk menampilkan panel di area notch menggunakan
[DynamicNotchKit](https://github.com/MrKai77/DynamicNotchKit), lengkap dengan
Timer & Pomodoro, Music, Baterai, Kalender, dan File Shelf.

## Prasyarat

- macOS 13 atau lebih baru
- Xcode 15 atau lebih baru (diuji dengan Xcode 27.1)
- XcodeGen — opsional, hanya dibutuhkan bila ingin membuat ulang project dari `project.yml`

## Menjalankan

1. Buka `Sela.xcodeproj` di Xcode.
2. Pilih scheme **Sela** dan destination **My Mac**.
3. Tekan `Cmd + R`.
4. Klik **Tampilkan Notch** (atau tekan `Enter`) untuk menampilkan panel notch.

Alternatif dari terminal:

```sh
xcodebuild -project Sela.xcodeproj -scheme Sela -configuration Debug \
  -derivedDataPath build build

open build/Build/Products/Debug/Sela.app
```

Jika `xcode-select` masih mengarah ke Command Line Tools, jalankan perintah build
dengan `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` di depannya.

## Timer & Pomodoro

- Sesi **Fokus** 25 menit dan **Istirahat** 5 menit, dipilih lewat tombol sesi di panel.
- **Mulai** menjalankan sesi, **Jeda** menghentikan hitung mundur sementara,
  **Reset** mengembalikan waktu ke durasi awal sesi yang dipilih.
- Panel menampilkan jenis sesi, sisa waktu, dan status (Siap, Berjalan, Dijeda, Selesai).
- Saat notch dirapatkan, pet di sisi kiri hanya muncul selama sesi timer berjalan;
  sisi kanan menampilkan pemberitahuan baterai bila ada, atau sisa waktu/"Sela".
  Saat timer belum dimulai, dijeda, direset, atau selesai, tidak ada pet.
- Timer berjalan di level aplikasi, jadi tetap berjalan ketika panel ditutup.
- Saat waktu habis, alarm berbunyi sekali dan status berubah menjadi **Selesai**.

## Baterai & charger

- Panel **Baterai** menampilkan persentase, kondisi (menggunakan baterai, sedang
  mengisi, atau terhubung ke charger tetapi tidak mengisi), dan tombol refresh.
- `BatteryModel` membaca data dari IOKit dan mendengarkan notifikasi perubahan
  sumber daya, dengan polling 15 detik sebagai cadangan.
- Memasang atau melepas charger membuka notch dengan kartu pemberitahuan di atas
  panel yang sedang aktif tanpa mengganti tab atau menghentikan timer. Jendela
  utama Sela juga menampilkan kartu yang sama. Setelah sekitar empat detik notch
  kembali ringkas bila timer berjalan, atau tersembunyi bila tidak ada aktivitas.
- Baterai 20% atau lebih rendah saat tidak terhubung ke charger memunculkan
  peringatan satu kali sampai baterai pulih di atas 20%.
- **Battery Alerts** di panel Baterai mengatur kedua jenis pemberitahuan tersebut
  dan pilihannya disimpan lewat `UserDefaults`. Status baterai tetap diperbarui
  ketika pemberitahuan dimatikan.
- Aturan pemberitahuan berada di `BatteryAlertPolicy` (tanpa AppKit) sehingga dapat
  diuji dengan data contoh: `bash Tests/run-battery-tests.sh`.

## Kalender & meeting

- Tab **Calendar** membaca kalender yang sudah terhubung di aplikasi Calendar
  melalui EventKit. Sela tidak membuat, mengubah, atau menghapus acara.
- Akses hanya diminta saat pengguna menekan **Allow Calendar Access**; membuka tab,
  refresh berkala, dan startup tidak memunculkan permintaan izin.
- Agenda menampilkan acara yang sedang berlangsung dan tujuh hari ke depan,
  berurutan acara berwaktu lalu acara sepanjang hari. Acara yang sudah berakhir,
  dibatalkan, atau ditolak pengguna tidak ditampilkan.
- Setiap acara menampilkan judul, tanggal, jam, dan lokasi bila tersedia.
  Tautan Google Meet, Zoom, Microsoft Teams, Webex, Whereby, atau Jitsi mendapat
  tombol **Join meeting**; tautan web biasa mendapat **Open event link**. Tautan
  hanya dibuka setelah tombol ditekan.
- Agenda diperbarui saat tab dibuka, saat kalender berubah, saat aplikasi aktif
  kembali, tiap 60 detik, dan lewat tombol refresh. Hasil query lama diabaikan
  dan agenda dibersihkan ketika izin dicabut.
- Tanggapan akses berada di `Sela/Calendar`; data agenda hanya di memori, tanpa
  log, disk, atau jaringan. Query EventKit berjalan di actor terpisah dan tidak
  membawa objek `EKEvent` keluar actor.
- Tes memakai provider dan acara sintetis: `bash Tests/run-calendar-tests.sh`.

## Inbox (eksperimental)

- Inbox bersifat opsional dan nonaktif setiap aplikasi dijalankan. Menyalakan
  **Baca banner aplikasi lain** tidak langsung meminta izin; tombol
  **Izinkan akses Accessibility** adalah satu-satunya jalur permintaan izin.
- Pengguna memilih WhatsApp, Telegram, dan/atau Messages; tidak ada sumber yang
  dipilih secara default. Pengguna dapat menjeda, melanjutkan, atau mematikan
  pembacaan. Membuka Inbox atau startup tidak memunculkan prompt.
- Sela hanya menyalin teks banner/alert Notification Center yang terlihat. Pratinjau
  tersembunyi, layar terkunci, dan Focus tidak dipaksa dibaca; jika teks tidak
  tersedia, Inbox menampilkan "Pratinjau tidak tersedia". Tidak ada screenshot, OCR,
  database aplikasi, atau isi percakapan.
- Item hanya berada di memori, tanpa log, disk, analytics, atau jaringan. Hapus
  riwayat Inbox tidak mengubah notifikasi sistem atau pesan asli. Tombol **Buka**
  hanya membuka aplikasi sumber, bukan percakapan tertentu.
- Notifikasi baru menampilkan indikator lonceng dan jumlah di tampilan ringkas tanpa
  mengganti tab, menghentikan timer, atau mengganggu drag/drop. Membuka tab Inbox
  menandai item sebagai dibaca.
- Jalur simulasi tetap tersedia lewat tombol tambah atau
  `open "notchapp://notify?title=Notifikasi%20uji&body=Contoh%20isi"`.
- Pembacaan banner nyata belum terverifikasi dan bergantung pada versi macOS/aplikasi.
  Status per aplikasi dan protokol uji ada di `Tests/InboxValidation.md`.
- Tes sintetis: `bash Tests/run-inbox-tests.sh`.

## Interaksi notch

- Mengarahkan kursor ke area kamera/notch membuka panel tanpa klik.
- Panel tetap terbuka selama kursor berada di area kamera atau di dalam panel.
- Setelah kursor meninggalkan seluruh area, panel berubah menjadi tampilan ringkas
  bila timer sedang berjalan, dan disembunyikan bila tidak ada sesi aktif.
- Ada jeda singkat sebelum meringkas atau menyembunyikan panel agar gerakan kursor
  tidak membuat tampilan berkedip.
- Posisi kursor dibaca dengan polling `NSEvent.mouseLocation`, jadi hover tidak
  memerlukan izin Accessibility.

## Pet

`PetView` menampilkan **Little Ameath** dari `public/pet-pomodoro/` di panel timer dan
di sisi kiri tampilan ringkas notch selama sesi berjalan. `pet.json` dibaca dari bundle
untuk nama dan path spritesheet, lalu tiga frame idle dipotong dari spritesheet 8x9
(sel 192x208) dan dimainkan ringan (~0.4 detik/frame) hanya saat sesi berjalan.
Pemberitahuan baterai sementara menggantikan sisa waktu di sisi kanan, dan animasi
dimatikan bila Reduce Motion aktif.

## Ikon

Ikon aplikasi berasal dari `public/sela-icon-light.png` dan dipasang lewat
`Sela/Assets.xcassets/AppIcon.appiconset` (ukuran 16–1024 px). Aplikasi hasil
build memakai ikon ini di Finder dan Dock.

## Struktur project

```
project.yml                   definisi project untuk XcodeGen
Sela.xcodeproj                project Xcode hasil generate
Sela/
  SelaApp.swift               entry point aplikasi
  AppDelegate.swift           penanganan URL notchapp://notify
  ContentView.swift           jendela utama
  NotchController.swift       pembungkus DynamicNotch dan aturan hover
  NotchHoverMonitor.swift     polling posisi kursor untuk area kamera
  InteractionAreaReporter.swift  pelaporan area panel yang benar-benar dirender
  BatteryModel.swift          status baterai dan pemantauan sumber daya
  BatteryAlertPolicy.swift    aturan pemberitahuan charger dan baterai rendah
  BatteryPanel.swift          tampilan panel baterai
  Calendar/CalendarModels.swift    agenda, filter, dan deteksi tautan meeting
  Calendar/CalendarService.swift   status akses dan pembaruan agenda
  Calendar/EventKitCalendarProvider.swift  provider EventKit read-only
  Calendar/CalendarPanel.swift     tampilan agenda dan tautan acara
  Inbox/InboxModels.swift     model Inbox, sumber, dan URL simulasi
  Inbox/InboxService.swift    riwayat memori, filter, jeda, dan kontrol izin
  Inbox/AccessibilityBannerObserver.swift  pembacaan banner eksperimental
  Inbox/InboxPanel.swift      tampilan Inbox dan kontrol eksperimen
  TimerModel.swift            status dan hitung mundur sesi fokus/istirahat
  TimerPanel.swift            tampilan panel timer
  CompactTimerLabel.swift     teks tampilan ringkas notch (waktu atau pemberitahuan)
  PetSpriteSheet.swift        pemuat pet.json dan pemotongan frame pet
  PetView.swift               animasi pet di panel
  Assets.xcassets/            ikon aplikasi
  Info.plist                  info bundle aplikasi
public/pet-pomodoro/          aset pet (pet.json + spritesheet), ikut ke bundle
```

## Cara kerja integrasi

- DynamicNotchKit ditambahkan sebagai Swift Package dependency
  (`https://github.com/MrKai77/DynamicNotchKit`, versi 1.1.0).
- `NotchController` membuat satu instance `DynamicNotch(style: .auto)`. Isi panel
  dibungkus `NotchExpandedContent` yang mengamati pilihan tab dan model baterai,
  sehingga tab dapat berganti dan kartu notifikasi charger muncul tanpa membuat
  ulang notch.
- Notifikasi baterai membuka notch selama beberapa detik dengan `BatteryAlertBanner`
  di atas panel aktif; `BatteryModel` menerbitkan `alert` yang dikonsumsi controller.
- Tab Calendar memakai `CalendarService` dengan provider EventKit read-only. Query
  berjalan di actor, sementara service mengatur status izin, refresh, dan snapshot
  agenda yang aman dipakai SwiftUI.
- Tab Inbox memakai `InboxService` bersama. Pembacaan banner eksperimental berada di
  `AccessibilityBannerObserver`; `AppDelegate` merutekan `notchapp://notify` ke
  Inbox tanpa memerlukan izin Accessibility.
- Aksi tombol memanggil API async bawaan library: `expand()`, `compact()`, dan `hide()`.
- `NotchHoverMonitor` memantau posisi kursor tiap 80 ms, sedangkan
  `InteractionAreaReporter` melaporkan area panel yang benar-benar dirender agar
  panel tidak dianggap ditinggalkan saat kursor berada di dalamnya.
- `TimerModel` memakai satu `Timer` berulang dengan toleransi yang menghitung sisa
  waktu dari deadline, sehingga tidak melenceng dan tidak bergantung pada UI.

## Membuat ulang project

Project Xcode digenerate oleh XcodeGen. Setelah mengubah `project.yml`, jalankan:

```sh
xcodegen generate
```
