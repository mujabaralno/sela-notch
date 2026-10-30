# Inbox validation

## Implementasi

- Inbox eksperimental nonaktif secara default. Membaca banner hanya setelah pengguna
  menyalakan fitur dan memberikan izin Accessibility lewat aksi eksplisit.
- `AccessibilityBannerObserver` membaca hanya window banner/alert Notification Center
  yang terlihat, tanpa screenshot, OCR, database aplikasi, atau percakapan.
- `InboxService` menyimpan item di memori, memfilter sumber terpilih, menjeda,
  membersihkan riwayat, dan membuang duplikat dalam jendela waktu.
- Jalur simulasi dan `notchapp://notify` tetap tersedia tanpa izin Accessibility.

## Hasil tes sintetis

`bash Tests/run-inbox-tests.sh` lulus. Tes memakai observer palsu dan data contoh
untuk memeriksa:

- parsing URL simulasi dan penolakan skema/host lain;
- fitur nonaktif tidak menerima banner, tetapi simulasi tetap masuk;
- sumber terpilih, deduplikasi, jeda/lanjutkan, kapasitas, tandai dibaca, dan hapus;
- status izin belum diberikan, permintaan izin hanya lewat aksi eksplisit, dan
  pencabutan izin;
- sumber kosong tidak memulai pembacaan.

Build Sela lulus dengan `AppDelegate`, skema URL `notchapp`, dan target macOS 13.

## Tahap 1 — pembacaan banner nyata

Lingkungan build: macOS 27.0.1. Percobaan banner nyata belum dilakukan.

| Sumber | Versi aplikasi | Status | Catatan |
| --- | --- | --- | --- |
| WhatsApp | 26.43.20 | Belum diuji | Perlu pesan uji yang disepakati dan izin Accessibility. |
| Telegram | Tidak terpasang | Belum diuji | Instal aplikasi lalu ulangi dengan pesan uji. |
| Messages | 26.0 | Belum diuji | Perlu pesan uji yang disepakati dan izin Accessibility. |

Tes otomatis tidak memberikan izin Accessibility dan tidak membaca kalender,
notifikasi, atau pesan pribadi. Karena itu fitur tetap ditandai eksperimental;
integrasi banner belum dapat diklaim berhasil untuk aplikasi mana pun.

## Protokol uji manual

1. Gunakan pesan uji yang disepakati. Jangan memakai isi pesan pribadi.
2. Jalankan Sela, buka tab Inbox, nyalakan **Baca banner aplikasi lain**, lalu tekan
   **Izinkan akses Accessibility**. Aktifkan Sela di System Settings bila diminta.
3. Kirim satu pesan uji dari WhatsApp, Telegram, dan Messages secara terpisah.
4. Catat macOS dan versi aplikasi, lalu tandai hasilnya **berhasil**, **terbatas**,
   atau **gagal**. Jangan menuliskan isi pesan ke repo.
5. Matikan pratinjau pesan di aplikasi sumber, lalu ulangi. Inbox harus menampilkan
   informasi yang tersedia atau "Pratinjau tidak tersedia", bukan isi tersembunyi.
6. Uji jeda, lanjutkan, matikan fitur, cabut izin Accessibility, dan hapus riwayat.
   Hapus riwayat tidak boleh mengubah notifikasi sistem atau pesan asli.
7. Pastikan timer, hover kamera, navigasi, dan drag/drop tetap bekerja.

## Batasan yang perlu dicatat

- Hanya banner yang terlihat dan terekspos di pohon Accessibility yang dapat dibaca.
- Focus, layar terkunci, atau pratinjau tersembunyi dapat membuat banner tidak
  menghasilkan cuplikan.
- Struktur Accessibility Notification Center dapat berubah antarversi macOS atau
  aplikasi. Dukungan per aplikasi tidak dijamin.
- Simulasi dan `notchapp://notify` hanya menguji Inbox, bukan menangkap banner asli.

Contoh simulasi aman:

```sh
open "notchapp://notify?title=Notifikasi%20uji&body=Contoh%20isi"
```
