# Sela

Aplikasi macOS untuk menampilkan panel di area notch menggunakan
[DynamicNotchKit](https://github.com/MrKai77/DynamicNotchKit), lengkap dengan
Timer & Pomodoro.

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
- Saat notch dirapatkan, sisi kiri menampilkan pet dan sisi kanan menampilkan sisa
  waktu selama sesi aktif (dan "Sela" saat idle), sehingga panel dan tampilan
  ringkas selalu sama.
- Timer berjalan di level aplikasi, jadi tetap berjalan ketika panel ditutup.
- Saat waktu habis, alarm berbunyi sekali dan status berubah menjadi **Selesai**.

## Baterai & charger

- Panel **Baterai** menampilkan persentase, kondisi (menggunakan baterai, sedang
  mengisi, atau terhubung ke charger tetapi tidak mengisi), dan tombol refresh.
- `BatteryModel` membaca data dari IOKit dan mendengarkan notifikasi perubahan
  sumber daya, dengan polling 15 detik sebagai cadangan.
- Memasang atau melepas charger menampilkan pemberitahuan singkat di notch tanpa
  mengganti tab atau menghentikan timer. Jika notch sedang tersembunyi, tampilan
  ringkas muncul sebentar lalu kembali tersembunyi.
- Baterai 20% atau lebih rendah saat tidak terhubung ke charger memunculkan
  peringatan satu kali sampai baterai pulih di atas 20%.
- **Battery Alerts** di panel Baterai mengatur kedua jenis pemberitahuan tersebut
  dan pilihannya disimpan lewat `UserDefaults`. Status baterai tetap diperbarui
  ketika pemberitahuan dimatikan.
- Aturan pemberitahuan berada di `BatteryAlertPolicy` (tanpa AppKit) sehingga dapat
  diuji dengan data contoh: `bash Tests/run-battery-tests.sh`.

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
di sisi kiri tampilan ringkas notch. `pet.json` dibaca dari bundle untuk nama dan path
spritesheet, lalu tiga frame idle dipotong dari spritesheet 8x9 (sel 192x208) dan
dimainkan ringan (~0.4 detik/frame) hanya saat sesi berjalan. Tampilan ringkas tetap
mengutamakan sisa waktu, dan animasi dimatikan bila Reduce Motion aktif.

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
  ContentView.swift           jendela utama
  NotchController.swift       pembungkus DynamicNotch dan aturan hover
  NotchHoverMonitor.swift     polling posisi kursor untuk area kamera
  InteractionAreaReporter.swift  pelaporan area panel yang benar-benar dirender
  BatteryModel.swift          status baterai dan pemantauan sumber daya
  BatteryAlertPolicy.swift    aturan pemberitahuan charger dan baterai rendah
  BatteryPanel.swift          tampilan panel baterai
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
- `NotchController` membuat satu instance `DynamicNotch(style: .auto)` dengan
  `TimerPanel` sebagai tampilan penuh, ikon timer di sisi kiri, dan sisa waktu
  di sisi kanan.
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
