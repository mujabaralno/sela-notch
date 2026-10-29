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

- Sesi **Fokus** 25 menit dan **Istirahat** 5 menit, dipilih lewat segmented control.
- **Mulai** menjalankan sesi, **Jeda** menghentikan hitung mundur sementara,
  **Reset** mengembalikan waktu ke durasi awal sesi yang dipilih.
- Panel menampilkan jenis sesi, sisa waktu, dan status (Siap, Berjalan, Dijeda, Selesai).
- Saat notch dirapatkan, sisi kanan menampilkan sisa waktu selama sesi aktif
  (dan "Sela" saat idle), sehingga panel dan tampilan ringkas selalu sama.
- Timer berjalan di level aplikasi, jadi tetap berjalan ketika panel ditutup.
- Saat waktu habis, alarm berbunyi sekali dan status berubah menjadi **Selesai**.

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
  NotchController.swift       pembungkus DynamicNotch (expand/compact/hide)
  TimerModel.swift            status dan hitung mundur sesi fokus/istirahat
  TimerPanel.swift            tampilan panel timer
  CompactTimerLabel.swift     sisa waktu pada tampilan ringkas notch
  Assets.xcassets/            ikon aplikasi
  Info.plist                  info bundle aplikasi
```

## Cara kerja integrasi

- DynamicNotchKit ditambahkan sebagai Swift Package dependency
  (`https://github.com/MrKai77/DynamicNotchKit`, versi 1.1.0).
- `NotchController` membuat satu instance `DynamicNotch(style: .auto)` dengan
  `TimerPanel` sebagai tampilan penuh, ikon timer di sisi kiri, dan sisa waktu
  di sisi kanan.
- Aksi tombol memanggil API async bawaan library: `expand()`, `compact()`, dan `hide()`.
- `TimerModel` memakai satu `Timer` berulang dengan toleransi yang menghitung sisa
  waktu dari deadline, sehingga tidak melenceng dan tidak bergantung pada UI.

## Membuat ulang project

Project Xcode digenerate oleh XcodeGen. Setelah mengubah `project.yml`, jalankan:

```sh
xcodegen generate
```
