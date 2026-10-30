# Calendar validation

## Implementasi

- Tab Calendar memakai EventKit read-only melalui `EventKitCalendarProvider` (actor).
- Agenda tujuh hari, filter acara selesai/batal/ditolak, dan deteksi tautan meeting
  berada di `CalendarModels` tanpa AppKit.
- `CalendarService` mengatur status izin, refresh, hasil query kedaluwarsa, dan
  pembersihan agenda saat izin dicabut.
- Panel tidak meminta izin saat muncul; permintaan hanya dari tombol
  **Allow Calendar Access**.

## Hasil tes sintetis

`bash Tests/run-calendar-tests.sh` lulus. Tes memakai provider palsu dan acara
contoh untuk memeriksa:

- filter acara yang sudah berakhir, dibatalkan, dan undangan yang ditolak;
- urutan acara berwaktu lalu sepanjang hari;
- deteksi Google Meet, Zoom, Microsoft Teams, Webex, Whereby, dan Jitsi;
- tautan web biasa sebagai Open event link, tautan non-HTTP diabaikan;
- pemuatan agenda setelah izin diberikan, pembersihan saat izin dicabut,
  kalender kosong, dan kegagalan pembaruan.

Build Sela juga lulus dengan framework EventKit dan purpose string kalender
(`NSCalendarsUsageDescription` dan `NSCalendarsFullAccessUsageDescription`).

## Belum diuji langsung

- Dialog izin EventKit nyata dan tombol **Allow Calendar Access** pada mesin ini.
- Isi kalender pribadi, perubahan jadwal nyata, pembatalan, dan undangan ditolak.
- Kembali dari System Settings setelah izin diaktifkan atau dicabut.
- Membuka tautan meeting nyata dari tombol Join meeting / Open event link.
- VoiceOver, Reduce Motion, dan beberapa layar.

Tes otomatis tidak meminta izin dan tidak membaca kalender pribadi. Tidak ada isi
agenda yang dicatat ke log, disk, atau jaringan.
