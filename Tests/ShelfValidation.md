# File Shelf — issue #24

## Implementasi

Checkout awal hanya memiliki Timer, Music dan Battery; Shelf ditambahkan dengan
layanan terpisah. Maksimal 12 URL file lokal disimpan di RAM tanpa memindahkan,
menggandakan atau menghapus file asli. Tidak ada riwayat permanen/cloud.
Deduplikasi memakai URL standar. Drop melebihi kapasitas menambahkan item yang
masih muat dan menjelaskan jumlah yang tidak diterima; item lama tetap ada.

Quick Look menghasilkan thumbnail dengan fallback ikon Workspace. Nama file,
jumlah/kapasitas, empty state, hapus satu/semua, dan status file tidak tersedia
ada di tab Shelf. Ketersediaan diperiksa saat tab tampil, aplikasi aktif kembali,
dan sebelum/sesudah drag keluar. File yang dipindahkan tidak dicari ulang.

Drop destination AppKit menjadi parent NSHostingView, bukan overlay penangkap
klik. Window NSPanel diturunkan dari screenSaver ke floating selama receiver
terpasang dan level awal dipulihkan saat receiver dilepas. Cache paket tidak diubah.
Shelf tersedia di jendela pendamping maupun panel notch/floating.

Pemantau hover yang sudah ada juga mengamati changeCount/types pasteboard drag
serta tombol mouse, tanpa timer atau permission baru. Drag file baru menuju
kamera/panel membuka Shelf; pasteboard drag lama tidak dianggap sesi baru.
Penutupan, tombol navigasi dan hapus titipan ditahan saat drag/drop berlangsung.
Outgoing NSDraggingSource mengirim NSURL file yang dipilih dengan operasi copy
saja. Item tidak dihapus pada sukses maupun pembatalan. Alarm timer tetap memakai
mesin/suara yang sama; perpindahan tampilan tidak memutus drag aktif. Prioritas
aktivitas yang ada dipertahankan; indikator Shelf ditambahkan setelah baterai.

## Verifikasi otomatis

- XcodeGen dan build scheme Sela (CODE_SIGNING_ALLOWED=NO): lulus.
- Tests/run-shelf-tests.sh: layanan dengan file sintetis lulus untuk kapasitas,
  duplikasi, overflow, file dipindahkan, penghapusan aman, dan pengamatan drag.
- Tes AppKit dengan NSDraggingInfo sintetis serta pasteboard terpisah: lulus
  untuk multi-file URL, copy-only, kapasitas, keluar target dan pemulihan level
  NSPanel. Ini tidak membuktikan drag Finder nyata. AppKit mencetak diagnostik
  sandbox-extension pada pasteboard sintetis; semua pemeriksaan isi/file lulus.
- Regresi MusicService/transport dan BatteryAlertPolicy dijalankan terpisah.

## Verifikasi UI nyata

macOS 27.0.1 (26A434). Build Shelf diluncurkan, tab Shelf dan empty state terlihat,
kontrol navigasi dapat diakses. Folder contoh dibuat/dibuka di Finder:

- Sumber: /tmp/sela-shelf-ui-test/source (14 file teks sintetis)
- Tujuan: /tmp/sela-shelf-ui-test/destination

Alat UI belum memberikan koordinat lintas-jendela/dwell drag yang dapat
memverifikasi pemindahan file Finder→notch→Finder secara andal. Pengujian manual
pengguna diminta dalam percakapan; belum ada hasil yang dikonfirmasi.

| Skenario nyata | Hasil |
| --- | --- |
| Drag satu/beberapa file Finder → notch | Belum diverifikasi |
| Tambahkan file ke Shelf penuh | Belum diverifikasi di UI; layanan/receiver sintetis lulus |
| Shelf → folder uji Finder | Belum diverifikasi |
| Shelf → aplikasi penerima file lain | Belum diverifikasi |
| Batalkan drag keluar, item tetap tersedia | Belum diverifikasi di UI; state layanan dipertahankan |
| Hapus titipan tanpa menghapus file asli | Lulus sintetis; belum diverifikasi di UI |
| File asli dipindahkan/dihapus | Lulus sintetis; belum diverifikasi di UI |
| Drag saat Timer berjalan / alarm selesai | Belum diverifikasi di UI |
| External display/floating, fullscreen | Belum diverifikasi |

Issue #24 tidak ditutup; kriteria Finder nyata tetap perlu dibuktikan dengan file
contoh. Tidak ada klaim semua tujuan mendukung file drop. File promise/unduhan
jarak jauh bukan file lokal dan tidak diimpor sebagai salinan otomatis.
