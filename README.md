# Sela

Aplikasi macOS dasar untuk mengintegrasikan [DynamicNotchKit](https://github.com/MrKai77/DynamicNotchKit).
Project ini hanya berisi inisialisasi dan contoh notch sederhana sebagai pondasi
pengembangan berikutnya.

## Prasyarat

- macOS 13 atau lebih baru
- Xcode 15 atau lebih baru (diuji dengan Xcode 27.1)
- XcodeGen — opsional, hanya dibutuhkan bila ingin membuat ulang project dari `project.yml`

## Menjalankan

1. Buka `Sela.xcodeproj` di Xcode.
2. Pilih scheme **Sela** dan destination **My Mac**.
3. Tekan `Cmd + R`.
4. Klik **Tampilkan Notch** (atau tekan `Enter`) untuk menampilkan contoh notch.

Alternatif dari terminal:

```sh
xcodebuild -project Sela.xcodeproj -scheme Sela -configuration Debug \
  -derivedDataPath build build

open build/Build/Products/Debug/Sela.app
```

Jika `xcode-select` masih mengarah ke Command Line Tools, jalankan perintah build
dengan `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` di depannya.

## Yang ditampilkan

- Jendela utama berisi tiga tombol: **Tampilkan Notch**, **Ringkas**, dan **Sembunyikan**.
- Notch muncul di tengah atas layar, berisi ikon dan teks "DynamicNotchKit aktif".
- Di Mac tanpa notch, DynamicNotchKit otomatis memakai gaya *floating*.
- Status notch di jendela utama ikut berubah sesuai aksi terakhir.

## Struktur project

```
project.yml              definisi project untuk XcodeGen
Sela.xcodeproj           project Xcode hasil generate
Sela/
  SelaApp.swift          entry point aplikasi
  ContentView.swift      jendela utama dan tombol kontrol
  NotchController.swift  pembungkus DynamicNotch (expand/compact/hide)
  NotchContent.swift     isi tampilan notch
  Info.plist             info bundle aplikasi
```

## Cara kerja integrasi

- DynamicNotchKit ditambahkan sebagai Swift Package dependency
  (`https://github.com/MrKai77/DynamicNotchKit`, versi 1.1.0).
- `NotchController` membuat satu instance `DynamicNotch(style: .auto)` dengan
  `NotchContent` sebagai tampilan penuh, ikon di sisi kiri, dan teks "Sela" di sisi kanan.
- Aksi tombol memanggil API async bawaan library: `expand()`, `compact()`, dan `hide()`.

## Membuat ulang project

Project Xcode digenerate oleh XcodeGen. Setelah mengubah `project.yml`, jalankan:

```sh
xcodegen generate
```
