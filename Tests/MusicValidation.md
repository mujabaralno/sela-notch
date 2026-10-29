# Issue #20 — hasil validasi

Lingkungan: macOS 27.0.1 (26A434); Brave 156.1.98.60. Pengujian nyata
hanya YouTube di Brave, sesuai batas terakhir pengguna. Tidak ada metadata/judul
video pribadi yang disimpan sebagai fixture, screenshot, atau laporan di repo.

## Implementasi

- Previous dan Next dibaca terpisah dari enabled MRCommandInfo milik sesi lokal
  Now Playing; bukan disimpulkan dari nama aplikasi atau prohibitsSkip.
- Payload memuat capability, metadata, PID, dan token snapshot. PID diperiksa
  sebelum/sesudah query; hasil query lama diabaikan. Notifikasi source, metadata,
  playback, dan supported commands memicu pembaruan tanpa polling media.
- Tombol membedakan capability adapter yang tidak tersedia dari command yang
  diketahui tidak diaktifkan sumber. Play/Pause mendukung toggle atau command
  play/pause terpisah sesuai state sumber.
- Klik mengirim token yang benar-benar dirender. Service menolak token lama;
  helper memeriksa token, capability dan PID lagi, lalu mengirim ke bundle sumber
  secara eksplisit. Tidak ada fallback command global dari jalur listener Sela.
- Paket lokal Vendor/MediaRemoteAdapter berisi source upstream pada revision
  5b6afde3f501a3da567e23bf7f23d562938a1809 beserta patch, provenance dan lisensi.
  Cache dependency tidak diubah. Framework dinamis, run.pl dan lisensi dibundel.

## Hasil

| Pemeriksaan | Hasil |
| --- | --- |
| XcodeGen dan build scheme Sela, signing off | Lulus |
| MusicService sintetis | Lulus: capability per tombol, token tampilan lama, capability unknown, state playback, lifecycle |
| Handler transport dengan API sintetis | Lulus: token lama/replay, legacy command global, PID berubah/hilang, generation berubah, simbol send tidak tersedia |
| Regresi BatteryAlertPolicy | Lulus |
| YouTube Brave: sesi aktif | Provider nyata mengenali Brave; title dan artist tersedia |
| YouTube Brave: cover | Tidak ada pada probe awal; kemudian cover nyata terlihat di panel Sela |
| YouTube Brave: capability | macOS melaporkan Previous, Next, Play, Pause dan Toggle aktif; tombol panel terlihat aktif |
| YouTube Brave: Play/Pause dan Previous/Next | Lulus uji manual pengguna, dikonfirmasi dalam percakapan. Agent tidak mengirim kontrol tambahan |
| Music dengan Timer | Uji UI nyata: Timer mulai 25:00, buka Music, kembali Timer 24:43 dan masih berjalan; Timer kemudian di-reset |
| Hover cover, cover compact dan prioritas visual Timer | Belum diverifikasi langsung pada area kamera |
| Perpindahan sumber aktif / sesi berakhir | Belum diuji nyata; pengaman diuji sintetis |
| Apple Music, Spotify, browser lain | Tidak diuji; di luar cakupan uji nyata yang dipilih pengguna |

## Batas

MediaRemote adalah SPI privat; simbol dan struktur bisa berubah. Tidak ada klaim
kompatibilitas universal atau jaminan Mac App Store. Capability yang aktif berarti
sumber mendaftarkan handler, bukan bukti bahwa handler akan menjalankan aksi.

Pemeriksaan PID/token dan target bundle mengurangi risiko command ke sumber
berbeda. macOS masih memilih sesi/player dalam aplikasi browser; atomic routing
ke tab browser tertentu tidak dijanjikan. Respons Play/Pause dan Previous/Next
di YouTube Brave telah dikonfirmasi pengguna. Pergantian sumber dan hover kamera
masih perlu dikonfirmasi sebelum seluruh kriteria issue dinyatakan selesai.

Issue #20 belum memenuhi semua kriteria dan tidak boleh ditutup berdasarkan
build, capability probe, atau tes sintetis saja.
