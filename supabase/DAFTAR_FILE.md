# Daftar berkas SQL Supabase

| Berkas | Status | Alasan |
|---|---|---|
| `migrations/001_phase1.sql` | Dipakai di [`schema_baru.sql`](schema_baru.sql) | Migration 001 digabungkan sesuai dependensi; koreksi khusus instalasi kosong diterapkan bila migration asal hanya memperbaiki data/schema lama. |
| `migrations/002_reviews.sql` | Dipakai di [`schema_baru.sql`](schema_baru.sql) | Migration 002 digabungkan sesuai dependensi; koreksi khusus instalasi kosong diterapkan bila migration asal hanya memperbaiki data/schema lama. |
| `migrations/003_secure_public_reviews.sql` | Dipakai di [`schema_baru.sql`](schema_baru.sql) | Migration 003 digabungkan sesuai dependensi; koreksi khusus instalasi kosong diterapkan bila migration asal hanya memperbaiki data/schema lama. |
| `migrations/004_plans_entitlements.sql` | Dipakai di [`schema_baru.sql`](schema_baru.sql) | Migration 004 digabungkan sesuai dependensi; koreksi khusus instalasi kosong diterapkan bila migration asal hanya memperbaiki data/schema lama. |
| `migrations/005_manual_checkout.sql` | Dipakai di [`schema_baru.sql`](schema_baru.sql) | Migration 005 digabungkan sesuai dependensi; koreksi khusus instalasi kosong diterapkan bila migration asal hanya memperbaiki data/schema lama. |
| `migrations/006_admin_purchases.sql` | Dipakai di [`schema_baru.sql`](schema_baru.sql) | Migration 006 digabungkan sesuai dependensi; koreksi khusus instalasi kosong diterapkan bila migration asal hanya memperbaiki data/schema lama. |
| `migrations/007_product_settings.sql` | Dipakai di [`schema_baru.sql`](schema_baru.sql) | Migration 007 digabungkan sesuai dependensi; koreksi khusus instalasi kosong diterapkan bila migration asal hanya memperbaiki data/schema lama. |
| `migrations/008_site_content.sql` | Dipakai di [`schema_baru.sql`](schema_baru.sql) | Migration 008 digabungkan sesuai dependensi; koreksi khusus instalasi kosong diterapkan bila migration asal hanya memperbaiki data/schema lama. |
| `migrations/009_pro_analytics.sql` | Dipakai di [`schema_baru.sql`](schema_baru.sql) | Migration 009 digabungkan sesuai dependensi; koreksi khusus instalasi kosong diterapkan bila migration asal hanya memperbaiki data/schema lama. |
| `migrations/010_recurring.sql` | Dipakai di [`schema_baru.sql`](schema_baru.sql) | Migration 010 digabungkan sesuai dependensi; koreksi khusus instalasi kosong diterapkan bila migration asal hanya memperbaiki data/schema lama. |
| `migrations/011_advanced_analysis.sql` | Dipakai di [`schema_baru.sql`](schema_baru.sql) | Migration 011 digabungkan sesuai dependensi; koreksi khusus instalasi kosong diterapkan bila migration asal hanya memperbaiki data/schema lama. |
| `migrations/012_digital_planners.sql` | Dipakai di [`schema_baru.sql`](schema_baru.sql) | Migration 012 digabungkan sesuai dependensi; koreksi khusus instalasi kosong diterapkan bila migration asal hanya memperbaiki data/schema lama. |
| `migrations/013_recurring_forecast.sql` | Dipakai di [`schema_baru.sql`](schema_baru.sql) | Migration 013 digabungkan sesuai dependensi; koreksi khusus instalasi kosong diterapkan bila migration asal hanya memperbaiki data/schema lama. |
| `migrations/014_admin_login.sql` | Dipakai di [`schema_baru.sql`](schema_baru.sql) | Migration 014 digabungkan sesuai dependensi; koreksi khusus instalasi kosong diterapkan bila migration asal hanya memperbaiki data/schema lama. |
| `migrations/015_support_content.sql` | Dipakai di [`schema_baru.sql`](schema_baru.sql) | Migration 015 digabungkan sesuai dependensi; koreksi khusus instalasi kosong diterapkan bila migration asal hanya memperbaiki data/schema lama. |
| `migrations/016_paid_catalog.sql` | Dipakai di [`schema_baru.sql`](schema_baru.sql) | Migration 016 digabungkan sesuai dependensi; koreksi khusus instalasi kosong diterapkan bila migration asal hanya memperbaiki data/schema lama. |
| `migrations/017_order_reviews.sql` | Dipakai di [`schema_baru.sql`](schema_baru.sql) | Migration 017 digabungkan sesuai dependensi; koreksi khusus instalasi kosong diterapkan bila migration asal hanya memperbaiki data/schema lama. |
| `migrations/018_rounding_receipts.sql` | Dipakai di [`schema_baru.sql`](schema_baru.sql) | Migration 018 digabungkan sesuai dependensi; koreksi khusus instalasi kosong diterapkan bila migration asal hanya memperbaiki data/schema lama. |
| `migrations/019_monthly_reports.sql` | Dipakai di [`schema_baru.sql`](schema_baru.sql) | Migration 019 digabungkan sesuai dependensi; koreksi khusus instalasi kosong diterapkan bila migration asal hanya memperbaiki data/schema lama. |
| `migrations/020_nullable_receipt_json.sql` | Dipakai di [`schema_baru.sql`](schema_baru.sql) | Migration 020 digabungkan sesuai dependensi; koreksi khusus instalasi kosong diterapkan bila migration asal hanya memperbaiki data/schema lama. |
| `migrations/021_private_receipts.sql` | Dipakai di [`schema_baru.sql`](schema_baru.sql) | Migration 021 digabungkan sesuai dependensi; koreksi khusus instalasi kosong diterapkan bila migration asal hanya memperbaiki data/schema lama. |
| `migrations/022_receipt_cleanup_storage_api.sql` | Dipakai di [`schema_baru.sql`](schema_baru.sql) | Migration 022 digabungkan sesuai dependensi; koreksi khusus instalasi kosong diterapkan bila migration asal hanya memperbaiki data/schema lama. |
| `migrations/023_review_photos.sql` | Dipakai untuk update; sudah digabung di [`schema_baru.sql`](schema_baru.sql) | Menambahkan penyimpanan metadata foto ulasan, bucket privat, policy upload/publikasi/admin, dan RPC foto publik. |
| `admin-bootstrap.sql` | Dipakai sebagai dasar `admin_setup.sql` | Langkah bootstrap admin lama dipindahkan dan diarahkan ke schema baseline baru. File asal tidak diubah. |
| `tests/admin_login.sql` | Abaikan karena hanya tes | Tes rollback-only untuk akun uji baru. |
| `tests/admin_purchases.sql` | Abaikan karena hanya tes | Skenario verifikasi/fixture; bukan bagian schema aplikasi. |
| `tests/advanced_analysis.sql` | Abaikan karena hanya tes | Tes rollback-only; berisi pembersihan awal fixture akun uji sehingga hanya untuk database/akun uji khusus. |
| `tests/digital_planners.sql` | Abaikan karena hanya tes | Tes rollback-only dengan fixture khusus; berisi hapus planner test di dalam transaksi rollback. |
| `tests/manual_checkout.sql` | Abaikan karena hanya tes | Skenario verifikasi/fixture; bukan bagian schema aplikasi. |
| `tests/order_reviews.sql` | Abaikan karena hanya tes | Skenario verifikasi/fixture; bukan bagian schema aplikasi. |
| `tests/phase3_parallel_cleanup.sql` | Berbahaya karena menghapus data | Menghapus fixture dan transaksi terkait; pembersihan manual setelah uji paralel saja. |
| `tests/phase3_parallel_setup.sql` | Berbahaya karena mengubah data (fixture COMMIT) | Membuat fixture persisten untuk uji paralel. Jangan jalankan saat setup project baru. |
| `tests/plans_entitlements.sql` | Abaikan karena hanya tes | Tes rollback-only; berisi pembersihan awal fixture akun uji sehingga hanya untuk database/akun uji khusus. |
| `tests/pro_analytics.sql` | Abaikan karena hanya tes | Tes rollback-only; berisi pembersihan awal fixture akun uji sehingga hanya untuk database/akun uji khusus. |
| `tests/product_settings.sql` | Abaikan karena hanya tes | Skenario verifikasi/fixture; bukan bagian schema aplikasi. |
| `tests/recurring.sql` | Abaikan karena hanya tes | Tes rollback-only; berisi pembersihan awal fixture akun uji sehingga hanya untuk database/akun uji khusus. |
| `tests/recurring_forecast.sql` | Abaikan karena hanya tes | Tes rollback-only; berisi pembersihan awal fixture akun uji sehingga hanya untuk database/akun uji khusus. |
| `tests/release_phase2.sql` | Abaikan karena hanya tes | Tes rollback-only; berisi pembersihan awal fixture akun uji sehingga hanya untuk database/akun uji khusus. |
| `tests/rounding_receipts_reports.sql` | Abaikan karena hanya tes; mengandung hapus fixture | Transaksi tes berakhir ROLLBACK, namun menjalankan mengandung perintah hapus objek/fixture. |
| `tests/site_content.sql` | Abaikan karena hanya tes | Skenario verifikasi/fixture; bukan bagian schema aplikasi. |
| `tests/support_content.sql` | Abaikan karena hanya tes | Skenario verifikasi/fixture; bukan bagian schema aplikasi. |

## Environment variables

Runtime aplikasi Supabase:

| Variabel | Pemakaian |
|---|---|
| `NEXT_PUBLIC_SUPABASE_URL` | URL project; dipakai client browser/server, middleware, API, URL aset Storage. |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | Public anon/publishable key; dipakai bersama URL project. Tidak ada service role key di kode aplikasi. |

Variabel tambahan untuk verifier/uji lokal (biasanya di `.env.rls-test`, bukan konfigurasi produksi):

| Variabel | Pemakaian |
|---|---|
| `RLS_TEST_A_EMAIL`, `RLS_TEST_A_PASSWORD`, `RLS_TEST_B_EMAIL`, `RLS_TEST_B_PASSWORD` | Kredensial dua akun khusus untuk verifikasi RLS. |
| `RLS_TEST_ALLOW_FIXTURES` | Harus `dedicated-test-accounts` untuk mengakui penggunaan akun uji khusus. |
| `RLS_TEST_APP_URL` | URL aplikasi lokal untuk verifier HTTP; default `http://127.0.0.1:3001`. |

Variabel build `MYBUDGET_BUILD_DIR` dan `MYBUDGET_LOW_MEMORY` juga dibaca oleh `next.config.ts`, tetapi bukan kredensial/koneksi Supabase.

## Catatan menjalankan

Jalankan hanya `schema_baru.sql` sekali pada project Supabase kosong, kemudian gunakan langkah manual di `admin_setup.sql` setelah akun admin didaftarkan dan email dikonfirmasi. Beberapa function aplikasi berisi operasi `DELETE` yang hanya berjalan saat fungsi terkait dipanggil (misalnya menghapus aturan berulang, review, atau metadata struk); schema setup tidak menjalankan penghapusan data saat dibuat. Jangan jalankan berkas tes berlabel berbahaya pada project produksi. Bucket QRIS, bukti pembayaran, receipts, aset situs, dan file digital dibuat sebagai konfigurasi; unggah aset resmi dan atur metode pembayaran melalui konfigurasi admin sebelum checkout dipakai.
