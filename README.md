# My Budget — Phase 1 dan Phase 2 bertahap

## Produk berbayar dan ulasan pesanan

Jalankan migration **016_paid_catalog.sql**, lalu **017_order_reviews.sql** setelah migration sebelumnya (termasuk 012 untuk digital_tool_products). Free tetap status default akun melalui trigger 004; tidak ada pembelian Free dan data pengguna lama dipertahankan. Katalog/checkout hanya menerima harga positif dari database. Review lama tidak dihapus, tetapi disembunyikan karena tidak memiliki pesanan terverifikasi. Kolom comment adalah proyeksi tersimpan dari body agar API ulasan lama tetap kompatibel.

`paid` berarti pembayaran telah disetujui admin, bukan sekadar konfirmasi pembeli. Pemilik dapat menulis/mengedit satu ulasan per pesanan paid dari **Paket → Riwayat pembelian → Beri Ulasan / Edit ulasan**. Nama awal dari profil, dapat disamarkan; rating 1–5, komentar teks biasa 10–500. Kiriman/edit menjadi pending, dengan jeda 30 detik per pengguna di database. Tulisan dirender sebagai teks React, tanpa HTML. Tulisan publik hanya approved melalui RPC proyeksi tanpa user_id/order_id; akses tulis langsung tabel ditolak, semua mutasi lewat RPC terotorisasi.

Admin membuka `/admin/reviews` untuk setujui/sembunyikan/hapus; cookie admin dan role database diperiksa kembali, mutasi memakai same-origin serta audit log. Publik melihat rata-rata, jumlah, tanggal, dan daftar terbaru pada beranda, 10 ulasan per halaman. Tidak ada data demo yang dianggap ulasan pembeli.

Uji manual: daftar akun baru → pastikan Free otomatis dan tanpa kartu Rp0 → buat pesanan berbayar dengan QRIS merchant yang sudah dikonfigurasi → konfirmasi → admin verifikasi transaksi nyata lalu setujui → kirim ulasan → pastikan belum publik → setujui melalui `/admin/reviews` → lihat beranda → edit (kembali pending) → sembunyikan/hapus di admin. Akun kedua dan pesanan pending harus ditolak; ulang kiriman cepat harus dibatasi. Untuk uji tanpa pembayaran gunakan `supabase/tests/order_reviews.sql` utuh di SQL Editor (fresh fixtures dalam BEGIN/ROLLBACK, berakhir PASS). Belum dijalankan live oleh agen; jangan gunakan fixture sebagai klaim pembayaran nyata.

## Kontak & bantuan

Verifikasi lokal: 61 tes, lint, dan TypeScript lolos. Build belum lolos karena lingkungan kehabisan memori/kegagalan penulisan artefak; jalankan ulang sebelum rilis. Migration dan publish CMS live belum diuji.

Halaman publik `/kontak` memakai WhatsApp bawaan 6288806001355. Nomor, pesan awal, dan jam balasan diatur pada **Kontak & bantuan** di `/admin/content`: simpan draft → preview → publish. Nilai publik membaca published, bukan draft. Jam bawaan “Jam balasan belum ditetapkan.”; isi jadwal dan zona waktu yang sebenarnya.

Jalankan `supabase/migrations/015_support_content.sql` setelah migration CMS 008; login admin memakai 014. Migration idempotent menambah validasi support, mengisi hanya field yang belum ada dan menaikkan revision draft yang berubah. Tidak mempublikasikan draft atau menimpa nomor yang telah diatur. Jalankan `supabase/tests/support_content.sql` utuh di SQL Editor hingga PASS (rollback); sebelum migration, konten legacy memakai fallback defaults.

Bantuan ada di footer landing, Pengaturan, checkout/riwayat pembelian. Pesan checkout hanya menambahkan ID pesanan dan nama produk, tanpa email/nominal/transaksi. Semua tautan WhatsApp dipicu klik pengguna, tidak fetch/pesan otomatis. Floating bantuan hanya dashboard pengguna login, bukan demo, dan berada di atas FAB/nav mobile. Nomor harus 62xxxxxxxxxx digits-only (10–15 digits), pesan maksimal 300 dan jam maksimal 120 karakter. URL selalu wa.me dan query di-encode; referrer tidak dikirim. Verifikasi live/visual dan WhatsApp nyata belum dilakukan; tidak deploy.

## Login admin langsung

Buka `/admin/login`, isi email/password akun Supabase yang telah ditambahkan pemilik ke admin_users. Tidak perlu login aplikasi utama. `/admin/connect` menjadi redirect. Server memverifikasi password melalui Supabase Auth, lalu is_admin; non-admin langsung sign out dari sesi login khusus tersebut dan mendapat pesan identik dengan password salah. Tidak ada role dari user_metadata atau UI untuk menaikkan role.

Jalankan migration `supabase/migrations/014_admin_login.sql` (memerlukan migration 005–006 yang sudah ada). Login fail-closed sebelum RPC baru tersedia. Jalankan `supabase/tests/admin_login.sql` utuh di SQL Editor sampai PASS: akun Auth sementara, anonymous/non-admin ditolak mencatat sukses, identity binding, retry audit idempotent, rate limit dan RLS. Semua BEGIN/ROLLBACK tanpa menyentuh akun admin asli/password. Jika gagal, ROLLBACK terlebih dahulu.

Rate limit database: 5 percobaan per hash email ternormalisasi/15 menit, lock serial lintas instance; bukan pembatasan IP. Attempt IDs tidak bisa didaftar klien. Failure telemetry anonim memerlukan UUID capability yang dihasilkan begin_admin_login; bukan bukti identitas. Audit sukses hanya dari JWT admin yang emailnya cocok. Password/token tidak masuk audit. Attempt telemetry dibersihkan setelah 7 hari; audit tetap append-only. Blok rate dicatat paling sekali per hash/15 menit.

Cookie mybudget_admin_session HttpOnly, SameSite Strict, Secure pada HTTPS, path `/` supaya API turut menerima cookie; maksimal 8 jam dan mengikuti expiry JWT yang lebih pendek (umumnya perlu login ulang lebih cepat). Tidak menyimpan refresh token atau memperpanjang sesi otomatis. Role/JWT diperiksa pada middleware dan tiap server handler; API admin tidak menerima bearer aplikasi utama sebagai pengganti cookie. POST/DELETE membutuhkan origin yang sama. Logout menghapus path baru dan lama, tanpa logout aplikasi utama; tidak menjanjikan pencabutan JWT yang telah diterbitkan sebelum expiry.

Unit test dan HTTP tanpa browser: `node scripts/verify-admin-login.mjs` dengan server localhost:3001 dan akun uji A non-admin/B admin. Skrip hanya mencatat status, tidak password/cookie. Live login/audit baru tetap perlu migration 014; laporan docs/admin-login-result.json. Visual dan HTTPS belum diuji, tidak deploy.

## Digital tools dan recurring Forecast — hasil terbaru

Empat planner tersedia di `/tools`: Budget, Savings, Freelancer finance dan Goal. Server mengecek pesanan **paid produk tepat**, bukan plan Pro saja; menghitung hasil/CSV dan menyimpan input tervalidasi dengan owner RLS. Hasil dihitung ulang saat dibuka. File pendukung opsional lewat riwayat pembelian, paid gate dan signed URL 60 detik; tidak ada URL publik permanen. Produk awal inactive; tidak ada pembayaran atau deployment nyata.

### Setup dan SQL

Sesudah migration 001–011 yang sudah terpasang, jalankan lengkap `supabase/migrations/012_digital_planners.sql`, lalu `supabase/migrations/013_recurring_forecast.sql` di SQL Editor. Jangan ulang migration yang sudah berhasil. Jalankan `.rls-digital-planners-test.sql` dan `.rls-recurring-forecast-test.sql` utuh hingga **PASS**; keduanya BEGIN/ROLLBACK. Langkah pengguna memakai authenticated + JWT sub; TEST orders bukan pembayaran. Bila gagal, `ROLLBACK;` sebelum mencoba lagi. Template di supabase/tests; file lokal gitignored tanpa key/password. Gunakan akun khusus pengujian.

Paralel membutuhkan fixture COMMIT agar dua API request melihat data yang sama: jalankan `.rls-phase3-parallel-setup.sql` hingga **READY**, `node scripts/verify-phase3-parallel.mjs`, lalu `.rls-phase3-parallel-cleanup.sql` hingga **PASS**. Setup terbatas akun A kosong: satu TEST rule, snapshot langganan; tanpa pembayaran/perubahan role admin. Verifier menjalankan dua apply bersamaan + retry, membersihkan fixture dan memulihkan langganan. SQL cleanup terakhir menghapus helper dan menjadi recovery jika proses terputus. Jangan ulang setup sebelum cleanup selesai. Setup belum dijalankan otomatis.

Ulang `node scripts/verify-phase3-remaining.mjs` setelah migration. Untuk HTTP tanpa browser, jalankan server lokal kemudian `node scripts/verify-phase3-http.mjs` (default localhost:3001; RLS_TEST_APP_URL boleh localhost lain). Memakai public key + akun lokal, tanpa menampilkan key. Gate checks tidak menggantikan owner SQL assertions.

### Sudah diuji

- Planner/regresi 48/48 passed. Suite Forecast 51: 50 passed, satu ekspektasi kalender dikoreksi; ketiga tests terkait diulang passed, 48 lainnya sudah passed. TypeScript/lint/build akhir passed.
- SDK live 5 checks dan HTTP localhost 15 checks passed: anonim 401, dua akun Free 403 untuk analytics/insights/reports/CSV. Laporan docs/phase3-remaining-result.json dan docs/phase3-http-result.json; server sementara dihentikan.

### Belum bisa diuji

- Migration 012–013 belum tersedia pada cek live: paid planner/isolation/ekspor, Forecast recurring/expiry/isolation dan paralel nyata pending owner SQL. Assertions Pro positif/expiry/isolation lengkap 009–011 belum diklaim PASS oleh cek gate ini.
- UI 375/768/1280 tidak diperiksa sesuai instruksi. Tidak deploy, tidak menguji merchant/QRIS/pembayaran nyata. CSV Premium Phase 2, referensi duplikat dan UI admin tetap terbuka.

### Keputusan diambil

SKU inactive: budget-planner/savings-planner/goal-planner Rp9.900, freelancer-planner Rp14.900; harga/status diatur admin. Akses tool mengikuti paid order, bukan expiry subscription. Planner tanpa bunga/jaminan; alokasi nol tidak memaksakan tanggal. Simpan input saja, output dihitung server. Batas integer nominal Rp1 triliun, horizon 1–1200 bulan, jumlah proyek 0–1000.

Forecast menambahkan income/expense recurring pada due-date; histori ledger dipisahkan dari baseline dan jadwal/budget memakai residual agar tidak ganda. Kuartil/median historis tetap skenario 30/60/90 hari; jadwal diasumsikan terlaksana. Due hari ini/terlewat perlu catch-up dahulu. Tanpa 013 health/projection memakai RPC lama, Forecast menampilkan konfigurasi belum tersedia. Goal tidak mengurangi saldo dua kali; tanpa API AI.

Bagian berikut adalah catatan sebelumnya; status terbaru di atas mengungguli catatan konfigurasi lama.

## Serah terima Sesi B — urutan SQL manual
Migration 001–005 sudah terpasang dan checkout dilaporkan PASS. **Jangan mengulang migration yang sudah terpasang.** Jalankan file lengkap di Supabase → SQL Editor → New query → Run, satu per satu:
1. `supabase/migrations/006_admin_purchases.sql` — review pembelian, audit, otorisasi admin. Lewati jika sudah berhasil diterapkan.
2. `supabase/migrations/007_product_settings.sql` — pengaturan produk/merchant, bucket file privat, hak unduh dan log.
3. `supabase/migrations/008_site_content.sql` — draft, preview dan publish landing.
4. Setelah migration, jalankan **secara manual** `supabase/admin-bootstrap.sql`. File ini mencari akun Auth `leufayyproduction@gmail.com` yang emailnya telah dikonfirmasi, lalu memasukkannya ke admin_users secara idempotent. Jika akun belum ada, daftar dan konfirmasi dulu. Tidak memakai user_metadata untuk role, tidak mengaktifkan Premium. File ini belum dijalankan oleh agen.

Masuk langsung dengan akun admin tersebut di `/admin/login`. Upload QRIS resmi melalui `/admin/settings` hanya setelah merchant dan verifikasi manual siap. CMS melalui `/admin/content`: simpan draft → buka preview → publish. Harga landing diambil dari katalog, bukan field harga CMS. Logo dapat diganti lewat aset tervalidasi atau memakai wordmark; icon tab tetap aset resmi awal.

### Sudah diuji
- Build akhir `.next-verify` lolos, termasuk lint dan TypeScript; 27/27 unit tests lolos (finance, checkout, admin, promo/upload, URL dan struktur CMS). Diff whitespace diperiksa.
- Phase 1 RLS serta Sesi A checkout sudah lolos sebelumnya; hasil SQL pengguna dibedakan dari eksekusi API agen.
- CMS disimpan pada commit `87cdee4`. Tidak ada browser, screenshot atau pengujian visual pada penutupan sesi ini.

### Belum bisa diuji
- Migration 006–008/SQL assertions Sesi B pada Supabase sungguhan belum terkonfirmasi. `verify:admin` masih blocked sebelum 006 diterapkan. SQL admin rollback disiapkan melalui `npm run verify:admin`; template pengaturan/CMS ada di `supabase/tests/product_settings.sql` dan `supabase/tests/site_content.sql`, memerlukan UUID dua akun uji khusus.
- Persetujuan paralel, upload/download byte sungguhan, UI admin/preview/publish live, ekspor CSV akun Premium live, serta tampilan Sesi B 375/768/1280 belum diverifikasi. SQL berurutan bukan bukti persetujuan paralel.
- Bootstrap admin belum dijalankan; QRIS merchant asli/pembayaran nyata dan deployment tidak dilakukan. Phase 2 keseluruhan belum dinyatakan lolos; jangan mulai Phase 3 sebelum verifikasi lengkap.

### Keputusan yang diambil
- Role admin hanya dari admin_users. Halaman memakai cookie access-token HttpOnly yang berumur pendek, diperiksa lagi di server; setiap API/RPC memeriksa role. Tidak ada service-role key.
- Review mengunci pesanan, menserialkan perpanjangan pengguna, memakai source_order_id unik, dan audit append-only. Pendapatan hanya status paid; tools dipisahkan dari langganan. Tidak ada policy admin pada transactions/budgets/goals.
- QRIS diunggah apa adanya; bukti dan file berbayar privat, signed URL 60 detik. Harga lama tetap snapshot. Early Access bukan lifetime; tools interaktif dan analitik Phase 3 masih Segera hadir.
- CMS memakai field terstruktur, validasi zod/database, revision untuk konflik edit, publik hanya membaca versi terbit, fallback default bila belum ada. Hosting komersial tetap mengikuti bagian "Hosting untuk penggunaan komersial"; tidak ada deploy produksi.

Website personal finance Indonesia. Phase 1 tersedia; Phase 2 sedang dilengkapi: paket/entitlement, laporan, ekspor CSV dan checkout manual. Admin/pengaturan/CMS adalah Sesi B. Tidak ada pembayaran otomatis, deployment, atau Phase 3.

## Checkout manual — Phase 2 Sesi A
Urutan migration: 001 → 002 → 003 → 004 → **005_manual_checkout.sql**. Jangan mengulang migration yang sudah terpasang. Migration 005 menambah products, payment_settings, orders, payment_confirmations, entitlements dan fondasi admin_users/is_admin. RLS aktif; pengguna hanya membaca pesanan/konfirmasi/entitlement miliknya. Semua tulisan pesanan lewat RPC; harga/masa akses/merchant/QRIS adalah snapshot dari katalog database. Route `/api/orders` memverifikasi JWT Supabase dan membuang nominal/plan/user_id dari browser. Tidak memakai service-role key.

- Harga produk Plus/Pro berasal dari products; plans tetap sumber kuota. Early Access default nonaktif, Pro 365 hari, promo/harga harus diatur admin nanti. Digital tools belum dijual.
- `pending` berakhir setelah 24 jam. `list_my_orders` mengubah pending yang lewat batas menjadi expired. Submitted tidak otomatis kedaluwarsa.
- Referensi wajib 3–120 karakter, catatan maksimal 1.000, bukti opsional. Konfirmasi hanya menghasilkan submitted, bukan paid/premium. Retry request UUID dan konfirmasi idempotent. Penolakan/persetujuan serta audit dibuat di Sesi B.
- Tambahan nominal pencocokan default mati. Jika admin mengaktifkannya nanti, alokasi 1–999 rupiah tidak dipakai pesanan pending/submitted lain dengan merchant/total yang sama; total dan tambahan disimpan di snapshot.
- Bucket `payment-proofs` **privat**, maksimal 5 MB, MIME JPEG/PNG/WebP. Path user_id/order_id/UUID.ext; upload hanya pemilik pesanan pending. RPC memeriksa path, keberadaan objek dan metadata ukuran/MIME. Bukti ditampilkan pemilik melalui signed URL 60 detik. Tidak ada URL publik permanen. Upload yang berhasil tetapi konfirmasi gagal dapat meninggalkan objek privat; pembersihan objek orphan perlu ditambahkan di admin/operasional nanti.
- Bucket `merchant-qris` publik hanya untuk gambar resmi yang memang ditampilkan ke pembeli; upload dibatasi admin. Jangan unggah bukti pengguna ke bucket ini. Kode tidak membuat, mengubah, atau mengedit payload/gambar QRIS.
- **QRIS belum ada: pembayaran belum tersedia dan create_order ditolak**. Jangan mengaktifkan payment_settings atau menerima pembayaran sebelum Sesi B/admin review dan QRIS resmi diverifikasi. Konfigurasi produk/merchant sementara hanya SQL pemilik proyek; UI pengaturan diselesaikan Sesi B.
- Admin pertama (saat Sesi B siap): cari UUID akun di Authentication → Users, lalu pemilik database menjalankan `insert into public.admin_users(user_id) values ('UUID-AKUN-ADMIN') on conflict do nothing;`. Role tidak berasal dari metadata pengguna; tidak ada UI elevasi sendiri. Admin belum memiliki halaman atau RPC persetujuan di sesi ini.

### Menguji tanpa pembayaran
`/checkout/demo` menampilkan contoh alur, tanpa QRIS, tanpa upload/pesanan/pembayaran/aktivasi. Form bisa disimulasikan, tetapi tidak mengubah Supabase. Label contoh selalu terlihat.
1. Terapkan migration 005 melalui SQL Editor → New query → Run.
2. Jalankan `npm run verify:checkout` dengan dua akun disposable di .env.rls-test. Skrip tidak membuat pesanan nyata, memeriksa API/RLS dan menyiapkan `.rls-checkout-test.sql` yang diabaikan git.
3. Jalankan seluruh `.rls-checkout-test.sql` di SQL Editor. Fixture QRIS/bukti hanya metadata sementara (tidak membuat gambar atau pembayaran). Tes memeriksa katalog/snapshot/retry, isolasi A/B, privatnya bucket, status, referensi, dan konfirmasi tidak mengaktifkan paket. Cari hasil PASS; seluruh transaksi berakhir **ROLLBACK**. Jika editor meninggalkan transaksi gagal, jalankan ROLLBACK sebelum ulang.
4. Regresi: `npm run verify:entitlements`, `npm run verify:phase1-rls`; lalu lint/test/typecheck/build. Persetujuan paralel/idempotent dan CMS diuji di Sesi B, belum diklaim tersedia.

Ekspor CSV Plus/Pro ada di `/api/exports/transactions`: hak akses dicek server lewat get_entitlement, SELECT memakai RLS pemilik, pagination 1.000 per query, output aman terhadap formula spreadsheet. Hindari mengedit transaksi bersamaan dengan ekspor besar; query per halaman bukan snapshot satu transaksi database.

### Admin pembelian — Sesi B
Setelah migration 005, jalankan `006_admin_purchases.sql`. Buat admin pertama lewat SQL pemilik: `insert into public.admin_users(user_id) values ('UUID-AKUN-ADMIN') on conflict do nothing;`. UUID dari Authentication → Users. Jangan menjadikan akun pengujian admin permanen. Tidak ada service-role key atau role dari user_metadata.
Masuk langsung di `/admin/login`. Server memverifikasi Supabase Auth dan is_admin, lalu menyimpan access token di cookie HttpOnly/SameSite Strict, maksimal 8 jam atau expiry JWT yang lebih pendek. Middleware/halaman/API memeriksa role ulang. Saat cookie/JWT habis, login kembali; tombol Keluar dari admin menghapus kedua path cookie. Refresh token tidak disimpan di browser/cookie admin.
Halaman `/admin` menampilkan ringkasan paid, daftar/filter, referensi duplikat, bukti signed URL 60 detik, catatan pemeriksaan dan audit. Admin wajib memeriksa penerimaan dana merchant; tombol persetujuan tidak membuktikan pembayaran otomatis. RPC mengunci baris dan menserialkan perpanjangan per pengguna; source_order_id unik, persetujuan ulang tidak menambah akses atau audit kedua. Paket sama diperpanjang sesudah masa sebelumnya; Plus/Pro berbeda tidak dikonversi atau prorata.
`npm run verify:admin` menyiapkan `.rls-admin-test.sql` dan menguji penolakan non-admin. Jalankan SQL itu sebagai pemilik di SQL Editor; seluruh fixture/admin sementara di-rollback. Persetujuan paralel masih membutuhkan pengujian terpisah; tidak diklaim teruji oleh SQL berurutan ini. Log append-only, transaksi/budget/goal pengguna tidak mendapat policy admin.

## Jalankan
### Produk, QRIS & file privat
Setelah 006 jalankan `007_product_settings.sql`. Bucket digital-files privat (PDF/CSV/XLSX, 20 MB) dan site-assets publik untuk logo (JPG/PNG/WebP, 2 MB) dibuat migration; payment-proofs tetap privat. `/admin/settings` mengedit produk, promo, durasi, harga dan urutan. Early Access aktif wajib memiliki awal/akhir promo. Upload file tools sebelum mengaktifkannya; produk file bukan janji tools interaktif Phase 3.
QRIS: pilih global/per produk, unggah gambar resmi DANA Bisnis (maksimal 5 MB), periksa tampilan dan nama merchant, isi instruksi, lalu simpan. Tidak ada QRIS bawaan/palsu atau edit payload. Pengaturan per produk yang enabled didahulukan dari global; disabled per produk berarti fallback global. Upload menghasilkan path baru, tidak menimpa gambar snapshot pesanan lama. Jangan menerima pembayaran sebelum merchant asli dan pengujian lengkap siap.
Pembelian file paid membuka tombol unduh di riwayat Paket. Server memeriksa order paid milik pengguna, mencatat penerbitan hak unduh di download_logs, lalu signed URL 60 detik. Produk nonaktif tetap dapat diunduh pembeli lama. Log mencatat permintaan akses, bukan bukti file selesai ditransfer. Admin asset/configuration masuk audit. Storage dan database tidak satu transaksi; file yang diunggah tetapi belum disimpan dapat menjadi orphan privat/publik dan perlu dikelola pemilik proyek.

Node.js 22+, `npm ci`, lalu `npm run dev`. Buka http://localhost:3000. Tanpa environment Supabase, klik **Coba demo interaktif**. Data demo tersimpan di localStorage browser ini; bukan akun atau penyimpanan aman untuk data sensitif. Landing memakai data contoh berlabel dan tidak memasukkannya ke akun.

`npm run typecheck`, `npm test`, `npm run build`, `npm start`.

## Supabase
1. Buat proyek Supabase milikmu. Jalankan `supabase/migrations/001_phase1.sql` di SQL Editor (database baru).
2. Salin `.env.example` ke `.env.local`. Isi project URL dan anon/publishable-compatible key. Tidak ada service-role key yang dibutuhkan frontend.
3. Auth → URL Configuration: Site URL adalah origin aplikasi. Tambahkan localhost:3000 dan origin produksi sebagai allowed redirect URLs. Aktifkan konfirmasi email dan konfigurasi SMTP produksi sesuai kebijakan Supabase.
4. Restart dev server. Daftar, konfirmasi melalui email, lalu isi onboarding. Reset password memakai tautan ke origin yang sama; event PASSWORD_RECOVERY membuka form password baru.
5. Uji dua akun sungguhan: akun B tidak dapat membaca/update/delete row akun A melalui REST. Insert dengan user_id akun lain harus gagal. Uji kategori_id milik akun lain juga harus gagal (composite FK). Admin/premium belum tersedia di Phase 1.

### Mengisi environment dan memeriksa koneksi
`.env.local` dibuat dengan nilai kosong dan diabaikan git. Jangan commit file ini.
Isi `NEXT_PUBLIC_SUPABASE_URL=` dengan Project URL dari Supabase → Project Settings → API.
Isi `NEXT_PUBLIC_SUPABASE_ANON_KEY=` dengan anon/public key (atau publishable key) dari Project Settings → API Keys. Jangan memakai service_role/secret key.
Hentikan terminal dev dengan Ctrl+C, lalu `npm run dev`. Buka http://localhost:3000/setup dan klik Periksa koneksi. Environment dan Supabase Auth harus Berhasil. Setelah login, ulangi cek agar tabel profiles turut diperiksa. Untuk production, `npm run build` ulang sebelum `npm start` karena variabel NEXT_PUBLIC ditanam saat build.

RLS diberlakukan di semua tabel pribadi. Kategori awal memakai enum nama tetap; kategori custom belum diekspos UI. category_id opsional disediakan untuk pengembangan kategori; composite FK memvalidasi kepemilikan bila digunakan. Mutasi langsung ke Supabase tunduk pada constraint DB dan RLS, bukan hanya validasi browser. Profile disimpan sebagai JSON terstruktur; tidak ada role/paket di profil. Tidak memakai Supabase Storage di Phase 1.

## Definisi keuangan
- Saldo: saldo awal + seluruh pemasukan aktual − seluruh pengeluaran aktual.
- Ringkasan bulan: hanya transaksi bulan yang dipilih. Saldo tetap saldo seluruh pencatatan.
- Aman dibelanjakan: saldo − sisa budget wajib (minimal nol tiap kategori) − rencana alokasi target aktif bulan terpilih. Ini indikator rencana, bukan jaminan keamanan keuangan. Nilai negatif tetap terlihat.
- Progres target: catatan dana yang sudah dialokasikan dari saldo, bukan transaksi terpisah. Tidak mengurangi saldo dua kali. Target tercapai tidak lagi ikut alokasi rencana.
- Patokan: rata-rata tiga bulan kalender selesai sebelum bulan terpilih, termasuk nol pada bulan tanpa transaksi; berbeda dari perkiraan onboarding. Riwayat pendek dapat menghasilkan patokan rendah.
- Proyeksi target: pembulatan ke atas (target − terkumpul) / alokasi bulanan, tanpa bunga; alokasi nol tidak punya estimasi.

## Hosting
Belum live. Target domain mybudget.biz.id perlu akses DNS dan konfigurasi hosting.
Vercel Hobby hanya untuk penggunaan personal nonkomersial: https://vercel.com/docs/plans/hobby. Penawaran premium berbayar memerlukan paket/provider yang mengizinkan komersial. Gunakan `npm run build` + `npm start` pada host Node lain; tidak ada dependency khusus Vercel.

### Hosting untuk penggunaan komersial
Vercel Hobby bukan pilihan untuk menawarkan paket atau tools berbayar. Sebelum peluncuran komersial, ganti paket hosting ke paket yang mengizinkan komersial, atau pindahkan aplikasi ke host Node.js yang sesuai. Periksa ketentuan dan biaya provider saat memilih; tidak ada jaminan operasional bisnis gratis.
Proyek memakai Next.js standar, bukan Vercel KV/Blob/Cron/Edge khusus. Build dengan `npm ci` dan `npm run build`, lalu jalankan `npm start` (PORT dapat ditentukan host). Saat pindah, atur dua environment Supabase di host baru, pindahkan DNS mybudget.biz.id, aktifkan HTTPS, serta ubah Supabase Site URL/allowed redirect URLs. Database/Auth tetap di Supabase sehingga tidak perlu memindahkan data hanya karena host aplikasi berubah. Storage privat dan konfigurasi merchant tetap perlu dibuat ketika slice terkait tersedia. Tidak ada deploy produksi atau konfigurasi deploy yang dibuat dalam sesi ini.

## Prasyarat Phase 2: verifikasi Phase 1 live
Phase 2 Sesi A tidak boleh dimulai sebelum isolasi dua akun Supabase sungguhan lolos. Unit test saja tidak membuktikan RLS. Hasil terbaru ada di `docs/phase1-rls-result.json`.
1. Jalankan migration 001 pada Supabase proyek uji. Jangan menjalankan ulang migration pada database yang sudah berisi tabel tersebut.
2. Daftarkan **dua akun khusus pengujian** lewat aplikasi. Konfirmasi email keduanya. Jangan onboarding dan jangan masukkan data keuangan pribadi. Skrip menolak akun yang sudah memiliki profile agar tidak mengubah profile lama.
3. Buka `.env.rls-test` yang sudah dibuat dan diabaikan git. Isi `RLS_TEST_A_EMAIL`, `RLS_TEST_A_PASSWORD`, `RLS_TEST_B_EMAIL`, `RLS_TEST_B_PASSWORD`. Isi `RLS_TEST_ALLOW_FIXTURES=dedicated-test-accounts` untuk menyatakan keduanya akun uji khusus yang boleh diberi fixture sementara. Jangan mengirim kredensial ke chat. Dua variabel public Supabase tetap di `.env.local`; service_role/secret key tidak diizinkan.
4. Jalankan `npm run verify:phase1-rls`. Skrip login sebagai A dan B, menguji baca/update/delete/insert lintas akun pada profiles/categories/transactions/budgets/goals dua arah, menguji FK kategori lintas akun serta validasi nominal/tanggal di database. Fixture dibuat hanya pada akun uji dan dihapus lewat pemiliknya di akhir; tidak menghapus akun Auth.
5. Status `passed` dan cleanup `passed` diperlukan untuk melanjutkan. `blocked` berarti verifikasi belum selesai; `failed` berarti cek tidak lolos. Laporan hanya memuat label hasil, tanpa token, email, password, user_id, atau data pribadi. Kegagalan cleanup perlu ditangani sebelum uji diulang.
Kasus tepi finance: `npm test`. Sesi A berikutnya: Reports → produk/entitlement → checkout manual. Sesi B terpisah: admin → QRIS/produk → CMS → verifikasi lanjutan. Tidak memulai Phase 3.

## Keterbatasan Phase 1
Checkout, admin, CMS, recurring, digital tools dan AI belum tersedia. Paket/entitlement dan Reports memerlukan migration 004 serta verifikasi live. Tidak meminta QRIS/PIN. Dark mode ditunda. Nominal saldo beranimasi ringan dengan reduced-motion; transaksi optimistic dengan rollback saat gagal, form mempertahankan isi saat error. Jangan mengklaim pembayaran/admin sudah tersedia.

Lihat PROGRESS.md untuk hasil verifikasi dan langkah berikutnya. Logo resmi terpusat di components/wordmark.tsx.

## Reports sederhana (Phase 2 Sesi A)
Menu **Laporan** memakai transaksi aktual akun: grafik enam bulan pemasukan (+) dan pengeluaran (−), tabel angka, kategori pengeluaran terbesar, serta perubahan terhadap bulan sebelumnya. Pengeluaran memakai pola garis agar seri tidak hanya dibedakan oleh warna. Saldo awal, perkiraan onboarding, dan alokasi target tidak masuk arus kas laporan.
Pembanding nol ditampilkan sebagai `Baru` atau `Tidak ada pembanding`; penurunan ke nol dari nominal positif tetap −100%. Bulan berjalan belum selesai. Perhitungan ada di `lib/finance/reports.ts`, diuji dengan `npm test`. Sesuai instruksi terbaru, seluruh halaman Laporan memerlukan Premium aktif: `reports_access` diperiksa database di RPC `get_report_transactions(month)` sebelum query. RPC tidak menerima user_id dan SECURITY INVOKER tetap memakai RLS Phase 1. Free melihat state terkunci dan CTA Paket tanpa data laporan. Dashboard Free hanya menampilkan arus kas bulan ini; grafik enam bulan dipindahkan seluruhnya ke Laporan Premium. Data transaksi pribadi tetap dapat dibaca pemilik untuk CRUD. Laporan lanjutan belum tersedia.

## Paket & entitlement — tanpa checkout
Urutan SQL: 001 → 002 → 003 → **004_plans_entitlements.sql**. Jangan mengulang migration yang sudah terpasang. Migration 004 menambah `plans`, `subscriptions`, RLS dan trigger kuota; semua akun lama dan registrasi baru mendapat Free. Tidak membaca role/plan dari user_metadata. Pengguna hanya SELECT langganan sendiri, tidak dapat INSERT/UPDATE/DELETE langganan atau konfigurasi paket.

Satu sumber kuota adalah row `plans`; satu sumber hak akses adalah `get_entitlement()` (hanya auth.uid(), tanpa argumen pemilik). Plus/Pro `active` dengan `expires_at > now()` mendapat Premium. Tidak punya langganan, cancelled, expired, atau waktu tepat mencapai expires_at memakai Free otomatis tanpa cron. Row langganan boleh tetap berstatus active di penyimpanan setelah waktu berakhir; hak efektif sudah Free. Aktivasi saat ini hanya oleh pemilik database lewat SQL tepercaya; tidak ada UI/RPC aktivasi sendiri, layanan pembayaran atau checkout.

| Batas Free | Aturan |
| --- | --- |
| 50 transaksi | Per bulan tanggal transaksi, bukan waktu input |
| 8 kategori kustom | Total row categories; kategori bawaan tidak dihitung |
| 1 goal aktif | saved < target; target tercapai tidak dihitung |
| 5 kategori budget | Per bulan budget |

Plus/Pro tidak memiliki empat batas itu dan mendapat `reports_access=true`; Free false. Trigger database memeriksa kuota pada INSERT/UPDATE/upsert, dengan penguncian per pengguna untuk request bersamaan. Data lama di atas batas tetap bisa dibaca, dihapus, dan diedit dalam bucket kuota yang sama; menambah/memindahkan ke bulan penuh atau membuka lagi goal tercapai ditolak. Error menampilkan batas dan CTA Paket. UI kategori kustom belum ditambahkan di slice ini; tabel/API categories sudah dibatasi.

Verifikasi:
1. Jalankan migration 004 via Supabase SQL Editor → New query → Run.
2. `npm run verify:entitlements` menggunakan dua akun di .env.rls-test, public key saja. Skrip menguji penolakan Free/RLS/langganan dan menghasilkan `.rls-entitlements-test.sql` lokal yang diabaikan git (berisi UUID akun uji, tanpa password/key).
3. Jalankan seluruh `.rls-entitlements-test.sql` melalui SQL Editor sebagai pemilik database. Tes memakai `SET LOCAL ROLE authenticated` dan JWT sub A/B, menguji paket aktif/kedaluwarsa/tanpa paket, kuota tepat/lebih batas, edit/upsert legacy serta isolasi laporan. Harus muncul `PASS: all assertions` dan diakhiri `ROLLBACK`; tidak meninggalkan data/aktivasi. Jika gagal dan editor tidak menutup transaksi, jalankan `ROLLBACK;` sebelum mengulang. Jangan hapus rollback atau memakai akun pribadi.
4. `npm run verify:phase1-rls` untuk regresi isolasi yang sudah lolos. `npm run lint`, `npm test`, `npm run typecheck`, `npm run build` untuk cek lokal.

Build dapat memakai folder terpisah agar tidak bentrok dengan dev: di PowerShell jalankan `$env:MYBUDGET_BUILD_DIR='.next-verify'; npm run build`. Jalankan `Remove-Item Env:MYBUDGET_BUILD_DIR` sebelum kembali memakai perintah run standar. Folder verifikasi diabaikan git; tidak memakai fitur khusus hosting.

## Phase 3 Sesi A — Financial health, Forecast, Goal projection

### Phase 3 Sesi B — Advanced insights dan Advanced reports
Migration **011_advanced_analysis.sql** versi lengkap dijalankan sekali setelah 001–010. `/features/insights` dan `/features/reports` terhubung dari Paket. Source lokal selesai dan tested; akses Pro/expiry/RLS baru belum terverifikasi live sampai migration dan assertions dijalankan. Tidak ada deployment atau API AI. Recurring PASS dilaporkan pengguna; CSV Premium/referensi duplikat/UI admin Phase 2 tetap terbuka dan tidak dikerjakan.

Insights deterministik dari transaksi aktual: perubahan kategori versus bulan lalu sampai hari yang sama dan rata-rata 3 bulan, transaksi besar, hari pengeluaran terkumpul, serta kategori yang membaik. Ambang ada di `lib/finance/insights.ts`: minimum 3 transaksi kategori, perubahan Rp20.000/20%; patokan 3 bulan minimal 5 transaksi, kenaikan 50%; transaksi besar minimum Rp50.000/3× median dengan 5 pembanding; hari terkumpul minimum 10 transaksi bulan ini, total Rp50.000, 3 transaksi pada hari itu, porsi 35%. Prioritas besar → kenaikan → patokan → perbaikan → hari; maksimal 5. Asumsi bisa dibuka. Abaikan disimpan pada insight_dismissals milik pengguna, kunci berubah per bulan; Free/Plus/expiry tidak dapat menggunakan RPC atau menulis dismissal melalui RLS.

Reports memakai satu snapshot RPC JSON security invoker + auth.uid(), hanya Pro: periode utama/pembanding kustom (boleh overlap), tren multi-bulan dengan bulan kosong, rincian kategori dan daftar transaksi. Bulan parsial mengikuti tanggal terpilih; perbedaan durasi tidak dinormalisasi. Pembanding nol memakai Baru/Tidak ada pembanding, tanpa NaN/Infinity. Batas 731 hari per periode dan 50.000 transaksi gabungan ditolak bila terlampaui, tidak dipotong diam-diam; JSON RPC menghindari limit default row PostgREST. CSV dibuat `/api/advanced-reports?format=csv` sesudah RPC mengecek Pro, berisi ringkasan utama/pembanding, tren/kategori dan transaksi periode utama pemilik; quotes/formula diproteksi, no-store. Endpoint ekspor transaksi Phase 2 tidak diubah.

Sudah diuji: 41/41 tests slice insights dan 44/44 akhir reports; TypeScript/lint/build; HTTP anonim insights GET, dismiss POST, reports JSON dan CSV semuanya 401 (docs/advanced-analysis-http-result.json). Belum diuji: assertions Pro/expiry/isolation/dismissal dan CSV Pro live, UI 375/768/1280 (tanpa browser). Verifier live blocked karena migration 011 belum tersedia; jangan menyebut fitur sudah live.

Setelah SQL migration lengkap, jalankan `node scripts/verify-advanced-analysis.mjs`, kemudian seluruh `.rls-advanced-analysis-test.sql` gitignored di SQL Editor hingga `PASS: advanced analysis assertions; rollback removes fixtures and upgrades`. Template juga ada `supabase/tests/advanced_analysis.sql`; verifier mengisi UUID lokal, tidak key/password. Setup plan hanya owner, setiap fixture/query pengguna memakai SET LOCAL ROLE authenticated + request.jwt.claims; seluruhnya BEGIN/ROLLBACK dan gagal dengan assertion FAIL. Jika editor masih dalam transaksi gagal, jalankan `ROLLBACK;` terlebih dahulu. Empat Digital tools dan verifikasi keseluruhan Phase 3 masih terbuka, bukan scope sesi ini.

### Phase 3 Sesi B — recurring (slice pertama)
Jalankan migration `010_recurring.sql` setelah 009. Halaman `/features/recurring` tersedia sebagai implementasi lokal; live belum terverifikasi. Aturan Plus/Pro diperiksa RPC/server dan policy baca; ledger milik pengguna tetap terbaca untuk menandai asal transaksi setelah expiry. `loadData` melakukan lazy catch-up sebelum membaca transaksi; halaman recurring juga memiliki tombol catch-up. Tidak ada cron berbayar atau pembayaran otomatis.
Tanggal bulanan tetap berpatokan tanggal mulai: 31 → akhir Februari → 31 Maret. Catch-up maksimal 500 per panggilan; sisa diproses lewat tombol atau kunjungan berikutnya. Jeda melewati tanggal yang terlewat selama jeda; lanjut/perubahan jadwal mulai sesudah hari ini. Perubahan nominal berlaku untuk tanggal yang belum dibuat; transaksi lama tidak berubah. Hapus aturan/transaksi tidak menghapus ledger, sehingga due date tidak dibuat ulang. Pengguna hanya dapat mengubah rule lewat RPC dan tidak dapat menulis ledger. Advisory lock memakai urutan yang sama dengan trigger kuota; primary key rule_id + due_on adalah pengaman idempotensi terakhir.
Verifikasi: `node scripts/verify-recurring.mjs` memakai public key dan akun lokal, menghasilkan `.rls-recurring-test.sql` gitignored. Setelah migration 010 terpasang, jalankan SQL itu di SQL Editor sebagai pemilik; setup plan memakai role owner, fixture finansial memakai `SET LOCAL ROLE authenticated` + JWT sub pengguna. Assertions berakhir PASS atau exception FAIL; BEGIN/ROLLBACK menjaga fixture dan upgrade tidak permanen. Jika transaksi editor sebelumnya gagal, jalankan `ROLLBACK;` dahulu. Untuk komputer dengan RAM terbatas, PowerShell: `$env:MYBUDGET_LOW_MEMORY='1'; $env:NODE_OPTIONS='--max-old-space-size=768'; $env:MYBUDGET_BUILD_DIR='.next-verify-recurring'; npm run build`. Opsi satu worker/optimisasi hanya aktif lewat flag tersebut, bukan konfigurasi deploy.
Sudah diuji: 38 unit tests penuh termasuk akhir bulan/tahun kabisat, minggu lintas tahun, batas akhir inklusif dan catch-up batch; TypeScript, lint dan build production (satu worker) passed. Belum diuji: SQL 010/RLS/generation dan panggilan paralel live (migration belum terpasang), UI visual sesuai instruksi. Integrasi recurring ke asumsi Forecast dan verifikasi keseluruhan Sesi B masih terbuka; jangan menganggap bagian 3 seluruhnya PASS. Insights, advanced reports/CSV laporan dan empat planner belum dikerjakan; tiga item Phase 2 tetap terbuka. Tidak deploy atau API AI.

Source lokal tersedia pada `/features/health`, `/features/forecast`, `/features/projection`. Jalankan `supabase/migrations/009_pro_analytics.sql` **setelah 001–008** melalui SQL Editor. Tidak ada deployment atau pembayaran nyata. `get_effective_plan()` membungkus resolver `get_entitlement()` yang sudah teruji, tanpa argumen user; active Pro/Early Access Pro saja. RPC security invoker menggunakan RLS dan auth.uid(), API tidak menerima user_id dan tidak menyimpan hasil analitik publik. Free/Plus/expiry ditolak; simulasi alokasi disimpan hanya setelah konfirmasi, lewat RPC owner-only. UI memeriksa akses saat fokus dan setiap 60 detik; request server selalu memeriksa ulang.

Sudah diuji: unit test deterministik health/forecast/projection (nol, data minim, bulan kosong, pemasukan tak stabil, Rp20.000, target tercapai, alokasi bersaing, akhir bulan), lint/TypeScript/build lokal. Belum diuji: migration 009 pada Supabase live, Pro/expiry/isolation RPC baru, UI 375/768/1280 (tanpa browser sesuai instruksi). Jangan mengartikan implementasi lokal sebagai fitur live terverifikasi. Tiga item Phase 2 tetap terbuka: CSV Premium positif, deteksi referensi duplikat, UI admin.

Keputusan rumus: maksimal 6 bulan kalender selesai, mulai bulan transaksi pertama; bulan kosong termasuk nol, bulan berjalan tidak digunakan sebagai patokan. Ini mengasumsikan pencatatan bulan pertama sudah lengkap. Health minimum 2 bulan + pemasukan/pengeluaran nonzero dan budget periode tersebut. Bobot tabungan/budget/cadangan/stabilitas: freelance/campuran 30/30/25/15, tetap 40/30/30. Surplus/pemasukan 20% mendapat skor tabungan penuh; budget: rata-rata 100 minus persentase kelebihan, dibatasi 0–100; saldo menutup 3 bulan pengeluaran mendapat skor cadangan penuh; stabilitas = 100 × (1 − koefisien variasi), dibatasi 0–100. Saldo hanyalah proksi cadangan, bukan bukti dana darurat terpisah.

Forecast minimum 3 bulan: kuartil 25/50/75 pemasukan, pengeluaran per kategori = max(rata-rata aktual, budget bulan ini), termasuk budget wajib. Semua pola memakai sebaran aktual, bukan perkiraan onboarding. Rentang 30/60/90 hari memakai laju merata per 30 hari; tidak memperkirakan tanggal invoice/gajian. Aturan recurring belum dibuat sehingga jadwalnya belum dimasukkan. Goal minimum 2 bulan untuk patokan median surplus; alokasi bersaing dibagi proporsional dan dibulatkan turun. Alokasi nol/tercapai ditangani langsung; proyeksi lebih dari 100 tahun tidak menampilkan tanggal. Goal tidak mengurangi saldo dua kali atau otomatis menjadi transaksi. Tidak ada API AI atau nasihat investasi.

Verifikasi live: `node scripts/verify-pro-analytics.mjs` menghasilkan `.rls-pro-analytics-test.sql` gitignored dari dua akun lokal, tanpa key/password dalam SQL. Jalankan SQL tersebut seluruhnya di SQL Editor: Free, Plus, expiry, Pro, isolasi A/B dan konfirmasi alokasi; semuanya rollback. Jika error, jalankan `ROLLBACK;`. Akun khusus pengujian wajib, role admin tidak diubah. Hasil live ditulis `docs/pro-analytics-result.json`; assertions owner tetap perlu hasil PASS dari SQL Editor. Sesi B/recurring/tools tidak dikerjakan.

## Logo dan ulasan pengguna

### Perbaikan view public_reviews
Setelah migration 001 dan 002, jalankan `supabase/migrations/003_secure_public_reviews.sql` di SQL Editor. File ini tidak menghapus data dan aman dijalankan ulang. Jangan menjalankan ulang 001/002 jika tabelnya sudah ada.
`public_reviews` adalah view; label UNRESTRICTED pada view bukan bukti tabel pribadi terbuka. Migration 003 menjadikannya security_invoker dan mencabut akses langsung API. Aplikasi membaca ulasan melalui RPC `list_public_reviews` dengan enam kolom publik yang tetap, limit maksimal 100, tanpa user_id/email/profil. Tabel reviews tetap memakai RLS kepemilikan. RPC ini sengaja SECURITY DEFINER untuk daftar ulasan publik; bukan akses bebas ke tabel pribadi.
Jalankan `node scripts/verify-public-reviews.mjs` setelah migration 003 untuk mengecek akses anonim/RPC tanpa menampilkan isi ulasan atau key. Label view di dashboard mungkin tetap ada, karena view tidak memiliki RLS sendiri; yang perlu diverifikasi adalah izin, security_invoker, dan RLS tabel dasarnya.
Logo resmi dari pengguna ada di `public/brand/mybudget-logo.png`, dirender lewat Wordmark. `app/icon.png` memakai gambar asli yang sama untuk ikon tab, tanpa membuat ulang logo.
Jalankan `supabase/migrations/002_reviews.sql` setelah migration 001 untuk mengaktifkan ulasan. Landing memiliki bagian Ulasan; halaman `/reviews` bisa dibuka dari footer dashboard. Pengguna login dapat menulis satu ulasan per akun dan memperbaruinya. Nama tampilan dan teks menjadi publik setelah persetujuan pada form; jangan masukkan informasi keuangan pribadi. Rating 1–5, teks 10–1.000 karakter, nama 2–60 karakter divalidasi browser dan database.
RLS tabel reviews hanya memberi akses row milik sendiri. Setelah migration 003, akses langsung public view dicabut; RPC daftar memproyeksikan hanya nama tampilan, rating, teks, ID ulasan, dan tanggal, tanpa user_id/email/profil. RPC ringkasan hanya mengeluarkan agregat rating. Timestamp ditetapkan DB dan tidak dapat diset browser. Tidak ada label pembelian terverifikasi palsu. Daftar menampilkan 20 ulasan terbaru, rating ringkasan mencakup semuanya. Moderasi/rate limiting tambahan belum tersedia.
Tanpa Supabase, satu ulasan demo bisa diisi, diperbarui, dan dihapus, disimpan lokal dengan label eksplisit; tidak dihitung sebagai testimoni pengguna sungguhan. `/reviews?demo=1` menyediakan uji lokal terpisah bahkan ketika environment Supabase sudah terisi. Mode ini tidak mengubah data atau hak akses server. Integrasi ulasan Supabase/RLS memerlukan migration 002–003 dan pengujian dua akun.

## Laporan bulanan, pembulatan, dan struk

Pada proyek ini migration 018 dan 019 sudah diterapkan; jalankan 020 lalu 021 bila belum terpasang. Untuk instalasi baru, jalankan 018 → 019 → 020 → 021 berurutan setelah 001–017 dan lewati migration yang sudah terpasang. 018 menambah preferensi laporan/pembulatan, audit nominal transaksi, dan bucket privat `receipts`; 019 menambahkan batas laporan di RPC; 020 menjaga `receipt_path` tidak diserialisasi sebagai JSON null sehingga tetap kompatibel dengan trigger null finance yang sudah ada; 021 memaksa bucket `receipts` private sekalipun record bucket sudah ada dan mengunci akses folder dengan policy pemilik. Pengguna Premium yang berhak melihat Reports dapat memilih bulan dalam rentang akun. Default rentang 3 bulan; admin dapat menetapkan 3 atau 6 bulan dari Pengaturan Admin. Riwayat lebih lama tetap tersimpan.

Laporan memakai nominal setelah pembulatan. Nilai awal disimpan terpisah dan pembulatan selalu ke atas ke Rp100, Rp500, atau Rp1.000. PDF dan CSV dibentuk di server sesudah RPC memeriksa hak akses dan rentang, hanya untuk transaksi pemilik. PDF memakai PDFKit karena project sebelumnya belum memiliki generator PDF; tidak ada dependency lain untuk format laporan. Foto struk maksimal 2 MB setelah kompresi, jpg/png/webp, dan disimpan di bucket privat. Penggantian/penghapusan menandai objek lama untuk pembersihan; aplikasi mencoba membersihkannya pada pemuatan atau perubahan data berikutnya. Bila storage gagal sementara, item tetap antre untuk percobaan ulang.

Tes lokal: `npm test`, `npm run typecheck`, `npm run lint`, `npm run build`. Untuk bukti database/RLS, jalankan `supabase/tests/rounding_receipts_reports.sql` di SQL Editor setelah migration 021; skrip memakai akun uji fiktif baru, role/JWT claims, transaksi `BEGIN … ROLLBACK`, memastikan bucket private, pembatasan baca/tulis/hapus lintas pemilik, pembulatan, penolakan JSON null, dan isolasi A/B, lalu harus menampilkan baris `PASS`. Skrip menambahkan policy permisif sementara di dalam transaksi untuk membuktikan restrictive owner guard tetap menolak akses lintas folder; ROLLBACK menghapusnya. Jangan gunakan akun pribadi atau service-role key. Pengujian UI manual: catat pengeluaran dengan pembulatan dan struk, buka Laporan, coba unduh PDF/CSV, lalu pastikan user lain tidak dapat membuka struk atau laporan tersebut. Fitur ini belum dinyatakan live sebelum SQL rollback test berhasil pada proyek Supabase tujuan.
