# Progress My Budget

## Laporan bulanan, ekspor, pembulatan, dan struk — 2026-10-12
- [done] Source: laporan multi-bulan dengan ringkasan, kategori, transaksi lengkap, pilihan bulan/rentang, perbandingan nol yang aman, dan unduhan CSV/PDF server-side. Scope data dan batas 3/6 bulan diperiksa lagi oleh RPC; endpoint tidak menerima user_id.
- [done] Pembulatan tersimpan sebagai nominal asli/hasil/selisih; trigger database menghitung ulang. Preferensi default per user. Struk dikompres di browser, dibatasi MIME/ukuran, disimpan di bucket privat dan hanya disajikan lewat signed URL singkat. Penggantian/penghapusan masuk antrean cleanup yang dicoba saat aplikasi dipakai.
- [done] Migration 018 (preferensi, audit pembulatan, metadata & kebijakan storage) dan 019 (RPC rentang laporan), SQL rollback test, unit tests, README setup. Ditambahkan PDFKit karena belum ada library PDF di project.
### Sudah diuji
- Unit tests 63/63 passed; `npm run lint`, `npm run typecheck`, dan production build passed. Build pertama menemui EPERM saat membuat folder output baru; ulang di folder output yang sama berhasil. Test SQL tersedia dengan akun fixture baru, role authenticated/JWT A/B/admin dan rollback.
### Belum bisa diuji
- Migration 018–019 dan `supabase/tests/rounding_receipts_reports.sql` belum dijalankan di proyek Supabase live pada sesi ini; RLS Storage/cleanup live perlu hasil `PASS` dari SQL Editor. Upload QRIS/pembayaran atau deploy tidak terkait dan tidak dilakukan.
- Tampilan 375/768/1280 tidak diinspeksi secara visual. Akses storage/unduhan end-to-end memerlukan konfigurasi Supabase dan pengguna uji.
### Keputusan diambil
- Rentang default 3 bulan kalender termasuk bulan ini; admin boleh memberikan 3 atau 6. Rentang diperiksa server-side; data historis tetap ada. Laporan tersedia hanya bagi entitlement `reports_access` aktif.
- Pembulatan selalu ke atas ke kelipatan yang dipilih; tanpa pembulatan memakai nominal asli. Laporan memakai nominal bulat dan turut mencantumkan nilai asli/selisih serta penanda ada struk.
- Cleanup bersifat lazy agar tidak memerlukan cron: objek yang sudah dilepas dari transaksi tetap terdaftar hingga Storage berhasil dihapus lalu RPC ACK. Kegagalan sementara dapat dicoba lagi saat penggunaan selanjutnya.
- Urutan SQL: 001–017 sesuai status project → 018 → 019; jalankan hanya migration yang belum diterapkan. Berikutnya: jalankan SQL rollback test di SQL Editor sampai PASS sebelum mengklaim verifikasi live.

## Perbaikan trigger JSON null untuk transaksi/struk — 2026-10-12
- [done] Temuan: `reject_null_finance_fields()` dari 001 dipasang pada `profiles`, `transactions`, `budgets`, `goals`; fungsi menolak nilai JSONB `null` mana pun di `data`, bukan kolom SQL tertentu. Constraint `*_required` menetapkan keys spesifik per tabel.
- [done] Penyebab: `normalize_transaction()` migration 018 selalu menggabungkan `receipt_path` bernilai SQL NULL ke JSONB sehingga menjadi `"receipt_path": null`; trigger `transactions_no_null` kemudian menolaknya. Form aplikasi mengirim `receipt_path: null` dan `saveItem` melakukan upsert pada `transactions`, jadi alur nyata terdampak juga.
- [done] Migration 020 menyesuaikan normalisasi agar menghapus key `receipt_path` saat kosong dan tetap menyimpan path bila ada. Skrip SQL rollback sekarang menguji pembulatan tersimpan, JSON null tetap ditolak P0001, serta isolasi transaksi/metadata/objek struk A-B.
### Sudah diuji
- 018–019 sudah diterapkan pengguna. Setelah patch, tes lokal 63/63, lint, typecheck, dan production build lolos. Build di direktori standar berhasil; build dengan direktori output khusus beberapa kali terkena EPERM pada pembuatan route folder.
### Belum bisa diuji
- Migration 020 dan SQL rollback test belum dijalankan di Supabase live. User perlu menjalankan 020 lalu `supabase/tests/rounding_receipts_reports.sql` dan memastikan hasil `PASS`; jangan menonaktifkan trigger.
### Keputusan diambil
- Daftar JSON keys wajib oleh constraint: profiles `name/pattern/purpose/opening/fixed/project/projects`; transactions `amount/type/category/description/date`; budgets `amount/category/month/mandatory`; goals `name/target/saved/monthly`. Trigger umum tetap menolak JSON null tambahan apa pun. Urutan migration project menjadi 001–019 yang sudah berjalan, lalu 020.
- Perbaikan lanjutan: skrip uji memiliki satu kurung tutup yang kurang pada pemanggilan `assert_true(rejects_null(format(...)))`; pasangan kurung, quote, dollar-quote kini lolos pemeriksaan statis. `psql`/Postgres lokal tidak tersedia, jadi eksekusi SQL live tetap menunggu SQL Editor.

## Katalog berbayar & ulasan pesanan — 2026-10-09
- [done] Source pricing/katalog hanya harga positif; Free tetap default subscriptions lewat trigger migration 004, tanpa menghapus akun/data. Migration 016 menonaktifkan produk nol dan menolak create_order/insert pesanan nol; admin productSchema sudah min 1.
- [done] Source migration 017: satu review per paid order, owner-only RPC, 30 detik antar submit, pending saat edit, moderasi/audit admin, projection publik tanpa UUID pengguna/pesanan, pagination 10. Legacy review dipertahankan hidden tanpa pesanan.
- [done] UI ulasan dari riwayat, form rating/nama/komentar 10–500, daftar publik dan admin /admin/reviews; profil sebagai nama awal, bisa disamarkan. Admin cookie/role/same-origin memakai guard yang ada.
### Sudah diuji
- 63/63 tes lolos (concurrency 1), TypeScript dan lint lolos; peringatan hook diperbaiki dan build production final lolos dengan satu worker. Tidak menambah dependency. Diff/check referensi Rp0 bersih pada source; Free di seed plans dipertahankan sengaja sebagai status akun.
### Belum bisa diuji
- Migration 016–017 dan SQL rollback order_reviews.sql di Supabase live, alur review/pembayaran end-to-end, visual mobile/tablet/desktop. Skrip memakai akun/produk/pesanan fiktif baru, role authenticated + JWT claims, hasil PASS/FAIL dan rollback; belum dieksekusi owner SQL.
- Pembayaran nyata, QRIS merchant dan deployment tidak dijalankan. Status verifikasi terdahulu tidak berubah.
### Keputusan diambil
- Selesai = paid, bukan submitted. Tulisan berupa plain text (HTML ditolak), mutation via RPC bukan grant insert/update bebas. Comment generated dari body untuk kompatibilitas API. Admin daftar 100 terbaru; public pagination 10 dan ringkasan semua approved.
- Migration 016 menjaga aturan digital_tool_products dari migration 012; tidak menimpa entitlement atau data pengguna. Langkah berikutnya: jalankan 016 lalu 017, SQL rollback hingga PASS, uji manual di README; jangan deploy sebelum verifikasi live.

## Pembaruan teks bantuan — 2026-10-04
- [done] Judul, pengantar, tujuan kontak, catatan keamanan dan 5 FAQ diganti sesuai arahan. Default pesan “Halo My Budget, saya butuh bantuan.”; layanan setiap hari 08.00–21.00 WIB, pesan di luar jam dibalas paling lambat 1x24 jam.
- [done] Checkout/riwayat memakai template {ID_PESANAN} ({NAMA_PRODUK}), substitusi hanya ID/nama produk. Pesan CMS tetap dapat diubah, termasuk memakai placeholder; setting tersimpan tidak ditimpa.
- Sudah diperiksa: patch konten/template; belum bisa diuji: tes terarah gagal sebelum assertions karena ENOMEM pada node:os. Tidak menjalankan build/browser/deploy.
- Keputusan: FAQ pemeriksaan pembayaran menyebut target 1x24 jam; tidak menambahkan rujukan Kebijakan Privasi yang belum diverifikasi. Default SQL hanya mengisi konten yang belum punya support; admin perlu edit draft → preview → publish untuk konten yang sudah tersimpan.

## Kontak & bantuan WhatsApp — 2026-10-04
- [done] Source /kontak: kendala login/pembayaran/akses, jam balasan dari CMS, tombol wa.me dengan pesan awal, 5 FAQ. Nomor bawaan 6288806001355; tidak ada pengiriman otomatis.
- [done] Bantuan di footer landing, Pengaturan aplikasi, checkout dan riwayat pembelian. Pesan konteks hanya order_number/product_name; email, nominal, bukti dan transaksi tidak ditambahkan. Link eksternal no-referrer/noopener; klik dan kirim dilakukan pengguna.
- [done] Support provider membaca konten published; CMS admin field phone/message/hours + preview draft, publish tetap melalui alur/audit yang ada. Migration 015 menambah validasi DB/idempotent dan mengisi defaults yang belum ada tanpa mengganti setting admin atau menerbitkan draft; revision draft naik saat backfill.
- [done] Tombol kecil keyboard/focus hanya dashboard pengguna login (bukan demo/landing/onboarding/halaman lain), mobile bottom 160px + safe area di atas FAB/nav. Tidak memakai API WhatsApp atau mengirim pesan.
### Sudah diuji
- 61/61 tes lolos dengan concurrency 1; lint dan TypeScript lolos. Tes nomor/URL memeriksa format Indonesia digits-only, batas input, escaping pesan dan hanya konteks pesanan.
- Test awal paralel gagal alokasi memori (18 file worker gagal, bukan assertions fitur); diulang berurutan dengan concurrency 1. Tanpa browser/screenshot/deploy.
### Belum bisa diuji
- Build belum lolos: runner kehabisan memori; percobaan ulang folder lama gagal menulis artefak UNKNOWN, folder baru juga terhenti saat kompilasi akibat tekanan memori. Ulangi build saat RAM tersedia, jangan anggap siap rilis.
- Migration 015/check constraints dan alur publish support Supabase live; template SQL rollback supabase/tests/support_content.sql siap, belum PASS SQL Editor. Visual 375/768/1280 dan membuka/mengirim WhatsApp tidak diuji sesuai instruksi.
- Prasyarat admin login 014/verifikasi rilis dan Phase 3 dari bagian terdahulu tetap pending; fitur kontak tidak mengubah status tersebut.
### Keputusan diambil
- Config terpusat support.phone/message/hours di CMS, code defaults hanya fallback legacy. Nomor ^62[1-9][0-9]{7,12}$ (10–15 digits), pesan 1–300, jam balasan 1–120 karakter. Jam bawaan belum ditetapkan, tanpa janji respons palsu.
- Tidak menerima URL WhatsApp bebas; helper selalu https://wa.me + nomor tervalidasi. Teks query di-encode. Floating button menuju /kontak, bukan membuka WhatsApp otomatis.
- Langkah berikutnya: migration 015 setelah CMS 008 (admin login memerlukan 014), uji support_content.sql sampai PASS, edit draft di /admin/content → preview → publish. Jangan deploy.

## Login admin langsung — 2026-10-03
- [done] Source /admin/login email/password Supabase Auth server; is_admin guard, generic error identik, non-admin signout lokal tanpa sesi admin. /admin/connect dan legacy session POST redirect login.
- [done] Cookie admin HttpOnly/Strict/root path, Secure HTTPS, cap 8 jam/JWT expiry; logout seluruh halaman menghapus root + legacy /admin. Halaman/API tanpa JWT/role valid redirect login; cookie-only API, same-origin mutation, role recheck server. Pembelian/unggah tidak bergantung sesi aplikasi utama.
- [done] Migration 014 rate limit 5/hash email normalisasi/15 menit dengan advisory lock; audit gagal nullable actor, sukses wajib role + email identity binding; nonce attempt tidak dapat didaftar, retry audit idempotent. Tanpa password/token audit atau service role.
### Sudah diuji
- 59/59 unit tests passed; 5 tests login terkait diulang setelah patch final dan passed. Password salah/non-admin hasil identik, signout/no acceptance, role + audit success mandatory, limit sebelum Auth request, cookie kedua path, redirect middleware tanpa sesi. TypeScript/lint passed; build/HTTP akhir dicatat pada hasil akhir di bawah.
- SQL rollback template memakai dua akun Auth baru, tanpa akun asli atau password; rate/role/audit tests prepared, belum PASS Supabase.
- Build production final passed (TypeScript/lint termasuk), targeted 5 tests final passed; HTTP localhost 11 checks passed: /admin/login 200, empat halaman admin dan empat API serta /admin/connect redirect tanpa sesi, missing-origin login 403. docs/admin-login-result.json berstatus passed_public_guards_configuration_pending; migration 014 belum tersedia. Server sementara dihentikan, belum klaim login/audit database live lolos.
### Belum bisa diuji
- Migration 014 belum dikonfirmasi terpasang; login admin/non-admin dan audit/rate limit database live menunggu SQL. HTTPS Secure, expiry JWT riil, lintas instance dan visual tidak diuji; tanpa browser/deploy.
- Sisa verifikasi rilis/Phase 3 dari bagian terdahulu tetap pending; fitur ini tidak menyelesaikannya.
### Keputusan diambil
- Rate per identitas, bukan IP; database konsisten antar instance. Attempt telemetry 7 hari; audit permanen append-only, throttle audit sekali/window. Anonymous failure events berbasis capability adalah telemetry, bukan identitas terverifikasi; hanya admin ber-JWT matching email dapat mencatat success.
- Tidak ada refresh cookie; masa sesi min(8 jam, expiry access JWT). Logout menghapus cookie, tidak menjanjikan revokasi access JWT sebelum expiry dan tidak logout aplikasi utama. Login fail-closed bila RPC/audit tidak tersedia.
- User metadata tidak dipakai untuk role. Path cookie diperluas ke / agar API memakai cookie; expiry eksplisit kedua path mencegah cookie lama /admin menutupi sesi baru. API bearer aplikasi utama tidak lagi membuka area admin.
- Langkah berikutnya: migration 014 → supabase/tests/admin_login.sql sampai PASS → ulang verifier login lokal. Jangan deploy atau mulai AI.

## Penutupan verifikasi rilis — 2026-10-03
- [done] Tes lokal ekspor Premium (handler server dipisahkan agar gate fail-closed dapat diuji), audit source/history, dan pengujian HTTP admin/CSV.
- [doing] Penutupan live Phase 2: bukan status siap rilis. Premium positif/expiry/isolation dan fixture duplicate positif-negatif menunggu SQL pemilik. Status bagian ini mengungguli catatan lama.
### Sudah diuji
- 54/54 unit tests passed, lint/TypeScript/build production passed. Tes handler: Free/resolver expired-as-Free/null ditolak sebelum baca data, kegagalan resolver ditolak, Plus/Pro CSV Rp20.000/formula escaping, error database tidak mengirim partial CSV. Expiry unit test memakai mock hasil resolver, bukan clock database.
- 36 checks Supabase/HTTP localhost passed: anonim/invalid JWT CSV ditolak; kedua akun Free CSV 403/no-store; non-admin enam endpoint admin baca/session/upload dan tiga endpoint mutation ditolak; empat halaman admin menolak non-admin 403; admin membuka keempat halaman 200. Cookie palsu/tanpa cookie redirect login; RPC non-admin 42501. Satu row pesanan admin memiliki flag duplikat boolean (bukan fixture duplikat positif). docs/release-phase2-result.json; server sementara dihentikan.
- Audit pola secret: 307 blob reachable history Git + tracked worktree, nol temuan literal secret/service-role JWT/private-key/pola credential. Tidak menampilkan isi secret. Bukan jaminan semua format credential atau reflog/backup sudah diperiksa.
- Semua tabel pada source migrations memiliki enable RLS; 15 route handler memakai verified-user/admin helper. RPC data pribadi memiliki auth.uid/RLS atau role/entitlement; fungsi publik ulasan sengaja proyeksi/agregat, helper validasi murni dan fungsi trigger tidak memerlukan hak pengguna. Tidak ada server action use-server ditemukan pada app.
- Source storage: payment-proofs/digital-files private; signed URL proof/download 60 detik, download setelah paid; public URL terbatas merchant-qris/site-assets. Tidak ada perubahan fitur/admin-role/payment pada live test ini.
### Belum bisa diuji
- Jalankan .rls-release-phase2-test.sql seluruhnya di SQL Editor hingga PASS: Plus aktif/expiry/isolation owner query, deteksi referensi case/whitespace duplicate versus unik, admin finance isolation, seluruh tabel public RLS dan flags bucket private. BEGIN/ROLLBACK; role authenticated + JWT pada langkah pengguna. Jika error jalankan ROLLBACK. File lokal gitignored, tidak ada key/password; template supabase/tests/release_phase2.sql.
- HTTP Premium positif + expired memerlukan fixture plan yang terlihat oleh server; kedua akun saat cek Free. Mock unit test tidak menggantikan tes live tersebut. Owner SQL rollback tidak dapat dilihat HTTP transaksi terpisah.
- Audit live katalog RLS, grants/policy/RPC yang dibuat di luar migrations dan file privat nyata belum diulang; pemeriksaan private-file byte pada sesi terdahulu sudah passed, bukan verifikasi terbaru. Phase 3 012–013/SQL/parallel masih membutuhkan hasil PASS; perbaikan sintaks 012 belum dianggap lolos SQL live.
- Visual 375/768/1280 tidak diuji sesuai instruksi; tanpa deploy/QRIS/pembayaran nyata/API AI.
### Keputusan diambil
- Mempertahankan source kebenaran get_entitlement() dan owner RLS ekspor; browser user_id diabaikan. Refactor helper server saja, kegagalan resolver/null fail-closed, route memakai no-store untuk sukses/error. Tidak ada bypass premium.
- Deteksi duplikat yang sudah ada tetap lower(btrim(reference)), di seluruh pesanan lain, bukan sekadar halaman filter; hanya admin menerima flag. Tidak menambah deteksi pembayaran otomatis atau persetujuan.
- Audit tidak mereset role/paket/data pengguna live. Fixture plan/order/reference dibuat hanya oleh pemilik dalam SQL rollback, tanpa pembayaran. Temuan pola/source nol tidak berarti audit DB live lengkap.
- Masih ada batas fungsi yang perlu ditinjau sebelum rilis tools: admin_save_product migration 007 meminta file pendukung untuk aktivasi digital_tool, walau checkout interactive 012 mengizinkan file opsional. Tidak diubah dalam audit keamanan ini.
- Langkah berikutnya: SQL rollback PASS dan tes HTTP Premium/expired dengan fixture terkontrol, lalu verifikasi Phase 3 yang tertunda; jangan mengklaim rilis/live sudah aman sepenuhnya.

## Hasil terbaru — tools/Forecast (2026-10-03)
- [done] Empat planner, paid-product server gate, simpan input owner-RLS, ekspor server; commit 4f87536. Forecast recurring income/expense dan residual tanpa duplikasi; commit 5757042. Navigasi /tools tersambung.
- [doing] Verifikasi live keseluruhan: migration 012–013 belum tersedia. Bagian ini mengungguli status historis di bawah; bukan klaim Phase 3 lengkap/live.
### Sudah diuji
- Suite planner/regresi 48/48 passed. Suite Forecast 51: 50 passed; satu ekspektasi kalender dikoreksi, ketiga tests terkait diulang passed (48 lainnya sudah passed). Suite penuh tidak diulang setelah koreksi.
- TypeScript/lint/build production akhir passed termasuk navigasi baru. SDK live 5 gate checks, HTTP localhost 15 checks passed: anonim 401, dua akun Free 403 analytics/insights/reports/CSV. Laporan docs/phase3-remaining-result.json dan docs/phase3-http-result.json. Server sementara dihentikan.
- RPC analytics/insights lama tersedia, bukan klaim assertions SQL 011 lengkap. SQL rollback dan verifier paralel disiapkan, sintaks/lint passed; owner SQL belum dieksekusi.
### Belum bisa diuji
- Paid/unpaid/Pro-tanpa-pembelian planner, simpan/isolation A-B/CSV paid, Forecast jadwal/expiry/isolation live menunggu 012–013 dan SQL PASS. Paralel nyata belum dijalankan; PASS recurring pengguna bukan bukti paralel.
- Pro positif/expiry/isolation assertions 009–011 bila belum PASS; UI 375/768/1280 tidak diuji sesuai instruksi. QRIS merchant/pembayaran nyata tidak diuji. Tidak deploy atau API AI.
- Tetap terbuka dan tidak dikerjakan: CSV Premium Phase 2, referensi duplikat, UI admin.
### Keputusan diambil
- SKU inactive: budget-planner/savings-planner/goal-planner Rp9.900, freelancer-planner Rp14.900. Tool memerlukan paid exact product, tanpa bypass Pro; akses paid tidak mengikuti expiry langganan. Harga/status melalui admin.
- Simpan input tervalidasi saja, output dihitung ulang server; savings/goal tanpa bunga, alokasi nol tanpa tanggal. Freelancer merupakan rencana, bukan jaminan. File pendukung opsional via riwayat pembelian, paid gate/signed URL 60 detik. Checkout tetap QRIS resmi/manual.
- Forecast memasukkan jadwal actual due-date, memisahkan histori ledger dan residual budget/jadwal; jadwal diasumsikan terlaksana. Due hari ini/terlewat perlu apply_recurring dahulu, warning backlog tampil. Goal bukan transaksi. Tanpa 013, health/projection memakai RPC lama tetapi Forecast menampilkan konfigurasi belum tersedia.
- Langkah berikutnya: migration 012 → 013; .rls-digital-planners-test.sql dan .rls-recurring-forecast-test.sql utuh sampai PASS (rollback). Paralel: .rls-phase3-parallel-setup.sql sampai READY → node scripts/verify-phase3-parallel.mjs → .rls-phase3-parallel-cleanup.sql sampai PASS. Setup COMMIT diperlukan untuk request berbeda; cleanup memulihkan langganan dan menghapus helper. Ulang verifier remaining/HTTP, jangan mulai AI.

## Sesi aktif — Digital tools, recurring/Forecast, verifikasi tersisa
- [done] Empat planner lokal, migration 012: pemetaan produk terlindung, paid gate (tanpa bypass Pro), inputs tersimpan owner-RLS, hitung/CSV server. Produk seed inactive; checkout interactive tanpa file opsional tetap memerlukan QRIS resmi dan verifikasi manual.
- [done] Integrasi recurring Forecast lokal + migration 013, jadwal tanggal aktual dan baseline tanpa hitung ganda. [todo] Verifikasi live baru/parallel/expiry + HTTP tanpa browser. Tiga item Phase 2 tetap terbuka. Tidak deploy atau AI.
- Sudah diuji: 48/48 unit tests planner dan regresi; TypeScript/build termasuk lint passed. SQL rollback template prepared; bukan PASS live. Halaman /tools (navigasi statis) ditambahkan sebelum build final nanti.
- Forecast: suite penuh 51 tests awal 50 passed; satu ekspektasi kalender diperbaiki (90 hari sejak 1 Oktober tidak mencakup 31 Desember). Tiga tests terkait diulang dan semuanya passed; 48 tests lainnya sudah passed. TypeScript/build termasuk lint passed. Bukan klaim suite penuh diulang.
- Live SDK tanpa mutasi: 5 pemeriksaan gate passed; RPC/migration baru belum tersedia (docs/phase3-remaining-result.json blocked_configuration). Dua SQL rollback lokal disiapkan. Paralel masih pending; PASS recurring pengguna tidak otomatis berarti paralel teruji.

## Sesi aktif — Advanced insights dan Advanced reports saja
- Recurring migration 010 terpasang dan uji PASS menurut pengguna; hasil ini user-reported, bukan eksekusi agen. Tidak mengulang slice recurring.
- [done] Insights lokal: fungsi murni/ambang/prioritas/maksimal 5, abaikan per akun dengan RLS dan Pro gate; migration 011 + SQL rollback. 41/41 tests, TypeScript dan build termasuk lint passed.
- [done] Advanced reports lokal: tren multi-bulan, periode utama/pembanding kustom, drill-down kategori ke transaksi, CSV laporan server setelah RPC Pro/owner. 44/44 tests, TypeScript/build termasuk lint passed. Digital tools dan tiga item Phase 2 tidak dikerjakan sekarang.
- Sudah diuji: 41/41 unit tests passed; TypeScript/build/lint passed. Tanpa browser atau API AI.
- Belum diuji: migration 011/RLS/dismissal Pro live, visual. SQL setiap langkah pengguna memakai role authenticated + JWT sub; setup plan owner-only dan semua rollback.
- Keputusan insight: perbandingan sampai hari sama, kategori minimum 3 transaksi; selisih Rp20.000 dan 20%; baseline 3 bulan minimal 5 transaksi +50%; outlier Rp50.000 dan 3× median minimal 5 pembanding; hari boros minimal 10 transaksi, total Rp50.000 dan porsi 35%. Maksimal 5, prioritas outlier/kenaikan/perbaikan/hari, abaikan per akun per bulan.
### Sudah diuji — insights/reports
- 41/41 tests slice insights, 44/44 akhir reports; typecheck dan production build termasuk lint passed. Finance tests: empty/zero/Rp20.000, ambang/prioritas/abaikan, overlapping/inclusive periods, bulan kosong, kategori, CSV quotes/formula escaping dan periode utama saja untuk detail transaksi.
- SQL rollback template/local lengkap: Free/Plus/expired denied, Pro succeeds, dismissal retry, write untuk B ditolak, data transaksi dan dismissal A/B tidak bercampur. Seluruh fixture finansial dibuat setelah role authenticated + JWT sub; validasi struktur 6 blok passed. Ini belum hasil SQL live.
- HTTP localhost tanpa browser: insights GET, dismissal POST, laporan JSON dan CSV anonim ditolak 401; docs/advanced-analysis-http-result.json. Server verifikasi sudah dihentikan. Tautan Paket/pricing menandai fitur baru masih diverifikasi.
- [done] Build final setelah navigasi/copy diperbarui passed (termasuk TypeScript/lint). Verifier terbaru lint/sintaks passed. Env dan SQL lokal gitignored; tidak ada key/password pada source atau laporan.
### Belum bisa diuji — insights/reports
- Migration 011 belum tersedia pada cek live; docs/advanced-analysis-result.json blocked. Pro/expiry/RLS RPC baru dan CSV Pro live menunggu SQL owner. Visual/browser tidak dilakukan sesuai instruksi. Tidak mengklaim fitur sudah live.
- Empat planner Digital tools, integrasi recurring pada Forecast, dan verifikasi keseluruhan Phase 3 masih terbuka, di luar scope sesi ini. CSV Premium Phase 2, referensi duplikat dan UI admin tetap terbuka.
### Keputusan — reports
- Maksimal 731 hari tiap periode dan 50.000 transaksi gabungan; lebih besar ditolak, bukan dipotong. Satu snapshot RPC JSON menghindari batas 1000 baris PostgREST/pagination berubah. Owner auth.uid + RLS, tidak menerima user_id browser. CSV endpoint khusus /api/advanced-reports?format=csv, tidak mengubah CSV Phase 2.
- Total aktual per periode, bukan saldo/alokasi goal. Bulan parsial terpilih dan kosong ditampilkan; pembanding nol Baru/Tidak ada pembanding. Durasi periode berbeda tidak dinormalisasi, asumsi dijelaskan. Detail transaksi utama saja; CSV juga memuat ringkasan pembanding, tren dan kategori pemilik.
- Langkah berikutnya: jalankan versi lengkap migration 011 sekali (sesudah 010), lalu .rls-advanced-analysis-test.sql sampai PASS, ulang verifier dan pengujian CSV Pro live. Berhenti setelah commit reports; tidak memulai planner atau AI.

## Phase 3 Sesi B — recurring dikerjakan lebih dahulu
- [done] Implementasi lokal recurring: migration 010, RPC Plus/Pro, ledger unik, lock pengguna, catch-up 500/panggilan, CRUD/jeda/lanjut, asal transaksi dari ledger. Tidak mengubah trigger kuota lama.
- [todo] Advanced insights → Advanced reports/CSV laporan → empat Digital tools → verifikasi live lengkap. Sesi A migration 009 terpasang menurut pengguna; hasil assertions akhir belum dilaporkan.
- Tetap terbuka dan tidak dikerjakan: CSV Premium Phase 2, referensi duplikat, UI admin. Tanpa browser/screenshot/deploy/AI.
### Sudah diuji — recurring
- 38/38 unit tests penuh passed (termasuk 3 recurring: 31/Februari/kabisat, minggu lintas tahun, catch-up/end/batch/repeat). TypeScript dan lint passed. Build production passed dengan MYBUDGET_LOW_MEMORY=1, heap 768 MB dan satu worker. Build sebelumnya gagal alokasi memori pada komputer sekitar 650 MB RAM kosong; cache baru dan mode opt-in mengatasi.
- Verifier menggunakan public key + akun uji, tanpa mutasi; SQL fixture dan env gitignored. Penanda recurring dibaca dari ledger, bukan field origin kiriman pengguna.
### Belum bisa diuji — recurring / sisa Sesi B
- Live blocked: migration 010 belum tersedia (docs/recurring-result.json). SQL rollback siap .rls-recurring-test.sql; Free/expiry/A-B/generation/edit/repeat belum diklaim passed live. Paralel live masih todo. UI 375/768/1280 tidak diuji sesuai instruksi.
- Advanced insights, advanced reports/CSV laporan, empat digital planner + paid gate, integrasi recurring pada Forecast, dan verifikasi lengkap bagian 3 belum dikerjakan.
### Keputusan — recurring
- RPC security definer terbatas selalu auth.uid + plan Plus/Pro, tanpa user_id browser; tabel rules/ledger tidak boleh ditulis langsung. Policy baca rules ikut entitlement; transaksi lama tetap terbaca setelah expiry.
- Ledger tidak ikut dihapus saat aturan/transaksi dihapus; unique(rule_id,due_on), per-user lock sama urutan dengan kuota. Tanggal 31 kembali ke 31 setelah bulan pendek. Jeda melewati masa jeda; lanjut/edit jadwal sesudah hari ini. Nominal edit berlaku untuk transaksi belum dibuat. Maksimal 500/panggilan; sisa tersedia lewat tombol/kunjungan berikutnya.
- Kapasitas sesi dipakai menyelesaikan slice paling berisiko hingga build stabil; berhenti setelah commit recurring. Langkah berikutnya: terapkan migration 010 dan jalankan SQL rollback sampai PASS, kemudian slice Advanced insights, Reports, Tools, dan verifikasi live/paralel. Tidak memulai AI.

## Phase 3 Sesi A — izin terbaru pengguna
- [done] Implementasi lokal Financial health, Forecast, Goal projection. Verifikasi live migration 009 masih terbuka. Sesi B dan AI tidak dikerjakan.
- Pengecualian gate eksplisit: RLS dan entitlement sudah lolos; tiga item Phase 2 tidak menghalangi Sesi A.
- Masih terbuka (tidak dikerjakan sekarang): CSV Premium positif, deteksi referensi duplikat, UI admin.
- Tanpa browser/screenshot; migration baru tetap perlu diterapkan sebelum verifikasi live fitur baru.
- [done] Slice Financial health: rumus murni, minimum 2 bulan penuh + budget/pemasukan/pengeluaran; UI asumsi, RPC Pro security invoker + owner filter. 29/29 tests, TypeScript dan build termasuk lint passed. Test awal sandbox ENOMEM; eksekusi ulang di luar sandbox passed.
- Belum diuji: migration 009/live Pro dan expiry baru; bukan klaim fitur live. Bobot freelance 30/30/25/15, tetap 40/30/30; referensi surplus 20%, cadangan 3 bulan.
- [done] Slice Forecast: 30/60/90 hari, rentang kuartil/median, tanggal negatif, tabel alternatif grafik. 32/32 tests, TypeScript/build/lint passed. Minimum 3 bulan penuh, maksimal 6; budget dan historis kategori memakai max agar tidak dihitung ganda. Recurring tidak dibuat/diasumsikan tersedia.
- [done] Goal projection: simulasi sementara, konfirmasi RPC Pro/owner, alokasi bersaing, nol/tercapai, akhir bulan. 35/35 tests passed; TypeScript/lint passed dan build final setelah tautan Paket/pricing diperbarui passed. Syntax/lint verifier passed, file env dan SQL fixture terkonfirmasi gitignored.
### Sudah diuji — Phase 3 Sesi A
- Unit finance: health kosong/minim/tidak stabil; forecast tiga skenario, nol, Rp20.000, negatif, budget tanpa duplikasi; projection nol/tercapai/bersaing/akhir bulan. Tidak ada perubahan saldo/transaksi dari simulasi.
- TypeScript, lint dan build lokal tiga slice; syntax verifier valid. Test penuh sekali pada akhir masing-masing slice (29/32/35 tests).
### Belum bisa diuji — Phase 3 Sesi A
- Verifier live: blocked, migration 009 belum tersedia (docs/pro-analytics-result.json). Tidak mengklaim RPC Pro/Plus/expiry/isolation baru sudah lolos live. SQL rollback siap di .rls-pro-analytics-test.sql, tanpa key/password.
- UI 375/768/1280 dan interaksi browser tidak diuji sesuai mode hemat. Tidak deploy, tidak ada pembayaran/QRIS nyata. Tiga item Phase 2 tetap terbuka seperti dicatat di atas.
### Keputusan — Phase 3 Sesi A
- Resolver Pro mengacu entitlement lama yang sudah teruji; RPC security invoker, owner filter, tidak menerima user_id. Hasil tidak disimpan pada tabel atau URL publik. UI recheck fokus/60 detik; konfirmasi selalu memeriksa server.
- Goal patokan median surplus 2–6 bulan, pembagian proporsional saat bersaing; tanggal hanya sampai 100 tahun, tanpa bunga atau jaminan. Simulasi tidak menyimpan sebelum konfirmasi, tidak menjadi transaksi.
- Pricing/Premium menandai implementasi lokal menunggu verifikasi live, bukan tersedia live. Recurring/insights/advanced reports/tools tetap Segera hadir.
- Langkah berikutnya: jalankan migration 009 lalu SQL rollback lokal sampai PASS, ulang verifier. Berhenti setelah Sesi A; jangan mulai Sesi B atau AI.

## Sesi aktif — Phase 2 Sesi B, admin/pengaturan/CMS
- Pengguna meminta verifikasi live Sesi B setelah migration 006–008 dan bootstrap selesai. Tanpa browser/screenshot, output dibatasi; Phase 3 tidak dimulai.
- [done] Implementasi checkout/pesanan: katalog produk, snapshot server, status pending/submitted/expired, bukti privat, riwayat. Migration 005 live dan verifikasi API passed; assertions SQL dilaporkan PASS oleh pengguna.
- QRIS resmi belum tersedia: jangan menerima pembayaran atau membuat pesanan yang tak bisa dibayar. Tidak deploy.
- [done] Verifikasi Phase 1 Supabase sungguhan: passed, cleanup passed (2026-10-02); laporan lokal diperiksa.
- [done] Sesi A: Reports → produk/entitlement → checkout manual
- [done] Implementasi Sesi B: admin → produk/QRIS → CMS. Commit admin 50df885; pengaturan f59e9be; CMS 87cdee4.
- [done] Verifikasi live yang diminta sesi ini: non-admin, idempotensi/paralel, isolasi finance admin, storage privat, draft CMS dan cleanup. Verifikasi visual/merchant dan sisa checklist Phase 2 belum dinyatakan lengkap.
- [done] Implementasi slice admin: migration 006, halaman/admin API terproteksi, audit, review atomik/idempotent, renewal serial. 23 tests, TypeScript dan production build termasuk lint lolos.
- Status admin terbaru ada pada hasil live di bawah: migration/RPC tersedia, non-admin ditolak, review ulang/paralel dan renewal passed. Verifier lama mengasumsikan dua non-admin; hasil blocked lama bukan status akhir. QRIS merchant nyata belum diuji.
- [done] Implementasi slice pengaturan: migration 007, katalog/promo/QRIS global/per produk, validasi aset, file privat dengan paid check dan log; 25 unit tests, TypeScript dan production build termasuk lint lolos. QRIS merchant asli tidak tersedia; migration/SQL live masih belum diuji.
- [done] Implementasi CMS: migration 008, zod + validasi database, draft/revision, preview admin, publish + audit, landing katalog dan logo terpusat. Build akhir termasuk lint/TypeScript lolos; 27/27 unit tests lolos. SQL CMS rollback PASS dilaporkan pengguna; akses API live dan cleanup dikonfirmasi agen.
- Phase 3 tidak dimulai. Tidak ada pembayaran nyata atau deployment.

### Verifikasi live Sesi B — sedang berjalan
- Migration 006–008 dan bootstrap dilaporkan sudah dijalankan pengguna. API live mengonfirmasi RPC/tabel admin dan CMS tersedia. Salah satu akun uji kini admin; role itu tidak dicabut atau ditingkatkan oleh agen.
- Sudah diuji: penolakan non-admin pada 8 RPC admin, 4 API baca, 4 halaman server (/admin, settings, content, preview); admin tidak dapat membaca/mengubah fixture transaksi, budget dan goals pengguna lain; anonymous/non-admin tidak membaca tabel draft/audit. Free CSV dan unduhan tanpa paid ditolak server. Fixture finance dibersihkan: passed.
- Laporan docs/session-b-live-result.json terbaru: passed_selected_checks, cleanup passed (file/order/entitlement fixture dihapus). Skrip verify:admin lama blocked karena mengasumsikan kedua akun non-admin; bukan kegagalan RLS. Verifier baru scripts/verify-session-b.mjs mengenali role yang ada tanpa mengubahnya.
- Sudah diuji tambahan live: dua review paralel menghasilkan satu reviewed + satu already_paid, satu entitlement dan satu audit. Review ulang tidak mengubah expiry; pesanan kedua menambah 30 hari setelah expiry sebelumnya. Admin tidak dapat menghapus audit langsung; pengguna biasa tidak dapat menulis status/snapshot/entitlement atau role sendiri.
- Sudah diuji storage live: byte PNG fixture tidak dapat diakses lewat URL publik/anon; pemilik dapat membaca byte yang sama dan admin signed URL 60 detik berhasil. Konfirmasi bukti tetap submitted tanpa entitlement. File CSV tool tanpa paid ditolak; setelah fixture paid, hak dan signed URL bekerja, URL publik ditolak. Seluruh fixture ini bukan pembayaran nyata.
- CMS SQL: pengguna melaporkan PASS dan setup READY; provenance disimpan docs/session-b-cms-sql-result.json (bukan eksekusi SQL agen). Public content tetap identik sepanjang tes API. Helper cleanup sudah dihapus dan dikonfirmasi scripts/check-session-b-cleanup.mjs (docs/session-b-cleanup-result.json passed).
- File SQL lokal gitignored disiapkan: .rls-session-b-cms-test.sql (rollback), .rls-session-b-setup.sql (empat pesanan TEST tanpa QRIS/pembayaran atau perubahan role), .rls-session-b-cleanup.sql (fixture/izin/helper khusus run ini). SQL setup belum dieksekusi agen. Manifest tidak mengandung password/key/JWT dan tetap gitignored.
- [done] Cleanup akhir: orders, confirmations, entitlements, products, download/audit fixture tidak tersisa; dua objek file tidak dapat diunduh lagi; helper tidak ditemukan; akun uji kembali Free; role admin tetap aktif; CMS tidak menyisakan headline test.
- Langkah berikutnya: berhenti setelah laporan sesi ini. Verifikasi visual/merchant dan sisa checklist Phase 2 hanya pada sesi yang diminta berikutnya; Phase 3 tidak dimulai.

### Sudah diuji — hasil akhir live sesi ini
- Live SDK/RPC + HTTP localhost tanpa browser: 8 RPC admin, API baca/mutasi, semua halaman admin/preview menolak non-admin; write role/status/snapshot/entitlement ditolak. Admin tidak membaca/mengubah transaksi, budget, goal pengguna lain dan tidak dapat menghapus audit secara langsung.
- Dua approval bersamaan: tepat satu entitlement dan audit. Retry tidak memperpanjang lagi; pesanan kedua menambah 30 hari setelah expiry pertama. Konfirmasi bukti hanya submitted, tanpa entitlement.
- Bukti PNG fixture: URL publik/anon ditolak, byte pemilik cocok, signed URL admin berhasil. Tools CSV: tanpa paid ditolak, sesudah fixture paid signed URL berfungsi, URL publik ditolak. Public content tidak berubah selama tes API.
- CMS assertions SQL rollback dilaporkan PASS oleh pengguna (docs/session-b-cms-sql-result.json); API akhir memastikan headline test tidak tertinggal pada draft/published.
- docs/session-b-live-result.json passed_selected_checks; docs/session-b-cleanup-result.json passed. Kedua skrip lint/sintaks lolos. Build/27 unit tests lolos sebelumnya; tidak diulang karena source aplikasi tidak berubah pada sesi verifikasi.

### Belum bisa diuji — hasil akhir live sesi ini
- Browser/screenshot/responsivitas dan interaksi UI admin tidak diuji sesuai instruksi. QRIS merchant asli, penerimaan pembayaran nyata dan deployment tidak dilakukan.
- Expiry signed URL tidak ditunggu 60 detik; URL diminta dengan TTL 60 detik dan diuji saat masih valid. CSV Premium positif, deteksi referensi duplikat dan isolasi antardua pengguna biasa pada pembelian/storage belum diulang di sesi ini (checkout dua pengguna biasa telah lolos Sesi A).
- Seluruh checklist Phase 2 belum dinyatakan lengkap; laporan mencakup pemeriksaan live yang diminta pada sesi ini. Phase 3 tidak dimulai.

### Keputusan — verifikasi live
- Public key, akun ordinary kosong dan admin yang sudah ada; tidak menaikkan/mencabut role, tanpa service role. Sign-out verifier scope local agar tidak menutup sesi browser akun yang sama.
- Empat order TEST dari SQL pemilik, tanpa QRIS/pembayaran; izin delete storage hanya dua path acak fixture dan helper hanya dapat dipanggil admin yang ditetapkan. Semua data/helper telah dihapus; SQL/manifest lokal gitignored dan tanpa key/password/JWT.

### Sudah diuji — penutupan Sesi B
- Build akhir .next-verify termasuk lint/TypeScript lolos; satu test penuh akhir 27/27 passed. Diff whitespace lolos. Tidak menjalankan ulang pengujian visual sesuai instruksi mode hemat.
- Gate Phase 1 RLS dan Sesi A checkout telah lolos pada sesi sebelumnya. Perubahan laporan RLS pengguna tidak ikut commit CMS.

### Belum bisa diuji — penutupan Sesi B
- Migration 006/007/008 live, assertions SQL admin/pengaturan/CMS, approval paralel, upload/download nyata, CSV Premium live, UI admin dan tampilan 375/768/1280 masih pending.
- Admin bootstrap belum dijalankan; merchant QRIS asli, pembayaran sungguhan dan deployment tidak dilakukan.

### Keputusan yang diambil — penutupan Sesi B
- Bootstrap manual supabase/admin-bootstrap.sql hanya untuk akun Auth leufayyproduction@gmail.com yang terdaftar dan dikonfirmasi; idempotent, tanpa role metadata dan tanpa aktivasi Premium.
- Urutan SQL tersisa: 006_admin_purchases.sql → 007_product_settings.sql → 008_site_content.sql → admin-bootstrap.sql. Lewati file migration yang sudah diterapkan; bootstrap bukan migration otomatis.
- Draft berversi terpisah dari publik; validasi URL/aset, preview admin, publish + audit. Pricing dari katalog. File tools privat setelah paid; fitur interaktif Phase 3 belum dibuat.
- Langkah berikutnya: pengguna menerapkan SQL manual, kemudian verifikasi live Sesi B dalam sesi lanjutan. Berhenti sekarang sesuai instruksi; Phase 2 keseluruhan belum lolos dan Phase 3 tidak dimulai.

### Checkout — serah terima Sesi A
- [done] Migration 005: products, orders, confirmations, entitlements, admin_users terproteksi, payment_settings, bucket bukti privat. RPC mengambil harga katalog, mengunci pesanan, dan konfirmasi tidak memberi paket.
- [done] Checkout dan riwayat pembelian; jika QRIS resmi belum tersedia, pesanan ditolak. Simulasi /checkout/demo diberi label dan tidak menghubungi RPC pembayaran.
- [done] Ekspor CSV server Plus/Pro: cek entitlement, query milik pengguna dengan RLS, pagination, perlindungan formula spreadsheet.
- Sudah diuji: 21/21 unit test; lint dan TypeScript; API anonim orders/CSV ditolak 401; simulasi konfirmasi tidak mengaktifkan Premium. Layout checkout contoh 375/768/1280 tanpa overflow horizontal, screenshot docs/checkout-demo-*.png.
- [done] Production build akhir lolos di .next-verify, termasuk lint/TypeScript dan semua route checkout/API. Environment lokal dan SQL akun uji terkonfirmasi gitignored.
- [done] Verifikasi API Supabase dua akun diulang: passed (docs/checkout-result.json). Pengguna melaporkan PASS assertions SQL dan rollback (docs/checkout-sql-result.json); hasil SQL dicatat sebagai user-reported, bukan eksekusi agen. Field SQL pending pada laporan API berarti skrip API tidak mengeksekusi SQL owner.
- Belum bisa diuji: CSV Premium live, upload/download byte bukti sungguhan, QRIS merchant asli dan pembayaran nyata. Admin persetujuan paralel/idempotent serta CMS adalah Sesi B, belum diimplementasikan.
- Keputusan: pending kedaluwarsa 24 jam saat dibaca; submitted tidak kedaluwarsa otomatis. Snapshot harga tidak berubah bersama katalog; request UUID dan konfirmasi idempotent. Bukti JPEG/PNG/WebP maksimal 5 MB, signed URL 60 detik. Nominal unik default mati; Early Access belum aktif; tools belum dijual.
- Langkah berikutnya: Sesi A selesai dan gate checkout lolos; sesi berikutnya Sesi B admin/QRIS/CMS dan verifikasi lengkap. Jangan mengulang migration 005. Phase 2 keseluruhan belum selesai; Phase 3 tetap belum dimulai.

### Slice paket & entitlement (instruksi terbaru)
- [done] Migration 004: plans menjadi sumber batas; subscriptions per user, backfill Free + trigger akun baru; pengguna hanya boleh membaca langganan sendiri.
- [done] Sumber kebenaran get_entitlement() tanpa argumen user; expiry/status diperiksa setiap panggilan; Free fallback untuk user tanpa paket/kedaluwarsa.
- [done] Trigger kuota: 50 transaksi/bulan tanggal transaksi, 8 kategori kustom, 1 goal belum tercapai, 5 kategori budget/bulan. Plus/Pro tanpa batas tersebut.
- [done] RPC get_report_transactions(month): reports_access wajib, security invoker + RLS Phase 1, hanya auth.uid(); UI tidak menerima data dashboard untuk laporan.
- [done] State terkunci + CTA ke Paket, halaman katalog/status; recheck akses pada fokus/60 detik, data laporan dibuang saat expiry.
- [done] Test SQL rollback untuk user tanpa paket, Free tepat/lebih batas, Plus/Pro aktif, kedaluwarsa, cancelled, edit/upsert data legacy, report A/B, write langganan/config ditolak.
- [done] Lint dan TypeScript lolos; 17/17 tests (16 finance + state terkunci tanpa data) lolos. Production build termasuk pemeriksaan lint/TypeScript lolos.
- [done] Migration 004 live terkonfirmasi melalui API. npm run verify:entitlements passed: Free RPC ditolak, langganan lintas pengguna tidak terbaca, insert/update langganan sendiri/lintas akun dan edit plans ditolak.
- [done] Pengguna melaporkan hasil akhir SQL Editor: PASS: all assertions; rollback removes fixtures and temporary upgrades. Mencakup Premium aktif/kedaluwarsa, semua kuota, data legacy, dan laporan A/B. Bukti dicatat terpisah di docs/entitlements-sql-result.json sebagai user-reported, bukan eksekusi agen.
- [done] Regresi live npm run verify:phase1-rls setelah migration 004: passed, cleanup passed. RLS dua akun, composite FK, validasi nominal/tanggal tetap lolos.
- [done] Visual state terkunci 375/768/1280: browser berhasil setelah preview dikompilasi dan tab dibuka ulang; tanpa overflow horizontal, tanpa chart/table/nominal laporan. Screenshots docs/reports-locked-{375,768,1280}.png; rincian docs/reports-visual-result.json.
- Sudah diuji: shape state terkunci tidak mengandung nominal/tabel/grafik, test finance tidak regresi, build berhasil, syntax skrip valid, environment dan SQL lokal akun uji gitignored. npm audit 0 setelah menambah alat lint development yang diperlukan.
- Sudah diuji tambahan: visual LockedReports dalam demo (komponen yang sama dengan Free), CTA membuka Paket, katalog Free/Plus/Pro sungguhan termuat; profil demo sementara dan viewport override dibersihkan. Lint/typecheck dan 17 tests lolos setelah perbaikan UX.
- [done] Production build akhir setelah perbaikan UX lolos (.next-verify); tidak ada perubahan SQL atau checkout pada sesi visual ini.
- Belum diuji di browser: UI laporan Premium aktif (akses/backend dan expiry sudah diuji SQL). Laporan docs/entitlements-result.json hanya memuat pemeriksaan API otomatis; field premium_sql_test pending di sana berarti skrip API tidak menjalankan SQL owner. Hasil SQL pengguna tersimpan terpisah di docs/entitlements-sql-result.json.
- Keputusan: plans berisi free/plus/pro; langganan satu row/user, status active/cancelled/expired, expires_at wajib bagi Premium. Aktivasi hanya SQL pemilik sampai admin/pembelian dikerjakan nanti. Tidak ada checkout atau pembayaran.
- Keputusan: batas diterapkan pada pertumbuhan kuota, bukan menghapus data. Edit/upsert dalam bucket lama tetap boleh setelah expiry, perpindahan bulan dan membuka lagi goal tercapai diperiksa ulang. Kategori bawaan tidak memakai kuota kategori kustom.
- Keputusan: arus kas enam bulan di Dashboard diganti ringkasan bulan berjalan, agar fitur Laporan Premium tidak terbuka lewat UI lain. Tidak ada data laporan sebagian pada state terkunci. FAB disembunyikan pada Laporan/Paket karena menutup manfaat di 375px; pemilih bulan hanya muncul setelah laporan dibuka untuk Premium.
- Langkah berikutnya: berhenti setelah slice paket/entitlement sesuai scope pengguna. Checkout dan Phase 3 tidak dimulai. Slice backend 0cba094; verifikasi database b844657; bukti visual dan perbaikan responsif disimpan pada commit sesi ini.

### Sudah diuji
- `npm test`: 12/12 finance tests lolos, termasuk data kosong, Rp20.000, saldo/alokasi negatif, goal nol/tercapai, pembulatan, lintas tahun.
- `npm run verify:phase1-rls`: Auth Supabase sungguhan dapat dijangkau dengan public key.
- Sintaks skrip verifikasi valid (`node --check`); .env.rls-test diabaikan git.
- Typecheck dan production build lolos. Tidak ada perubahan UI pada sesi prasyarat ini.

### Belum bisa diuji
- RLS live dua akun selesai: baca/update/delete/insert lintas pemilik ditolak dua arah; composite FK dan nominal/tanggal invalid ditolak; fixture dibersihkan.
- Reports mulai diimplementasikan; produk/entitlement dan checkout belum dimulai. QRIS merchant, pembayaran sungguhan dan hosting produksi belum dikonfigurasi.
- Hasil aman tanpa rahasia: docs/phase1-rls-result.json (status passed, cleanup passed).

### Keputusan yang diambil
- Patuhi gate pengguna: jangan membangun Phase 2 sebelum RLS live dua akun lolos.
- Verifikasi menggunakan anon/publishable key + dua akun khusus, bukan service_role/secret key.
- Akun uji harus baru, email dikonfirmasi, tanpa onboarding; fixture sementara dibersihkan, akun Auth tidak dihapus.
- Batas Free, perpanjangan entitlement, dan kedaluwarsa pesanan belum diimplementasikan/diklaim; ditetapkan pada slice Sesi A setelah gate lolos.
- Hosting komersial memakai paket/provider yang mengizinkan komersial, tetap portabel dengan Next.js standar.

Langkah berikutnya: lanjut Sesi A setelah gate RLS passed; selesaikan Reports, lalu produk/entitlement dan checkout manual. Migration 003 ulasan tetap perlu dikonfirmasi dengan node scripts/verify-public-reviews.mjs.

### Sesi A — Reports
- [done] Perhitungan murni lib/finance/reports.ts: enam bulan, kategori pengeluaran, perbandingan bulan; nol memakai Baru/Tidak ada pembanding.
- [done] UI Laporan terhubung ke data milik pengguna yang dimuat melalui RLS; data demo tetap lokal dan berlabel.
- [done] Unit test 16/16 dan typecheck lolos.
- [done] Production build termasuk TypeScript/lint bawaan Next lolos di .next-verify. Build awal pada .next gagal invariant /_not-found; folder verifikasi terpisah mengatasi benturan artefak dev/build.
- [todo] Uji visual 375/768/1280: browser preview gagal merespons CDP (tiga timeout). Tidak diklaim teruji; tabel angka tersedia sebagai alternatif grafik dan layout CSS mobile disiapkan.
- Keputusan: Reports sederhana memakai query transactions yang sudah teruji RLS; tidak perlu migration baru karena tidak menyimpan data turunan.
- Titik lanjut stabil: Reports sudah build lolos. Sesi A belum selesai; jangan menganggap paket/checkout sudah tersedia. Langkah berikutnya: uji visual Reports saat browser tersedia, lalu slice 2.2 products/entitlements + batas Free/CSV server, baru 2.3 checkout manual. Phase 3 tetap todo.

### Perbaikan akses ulasan publik
- [done] Source membaca RPC dengan kolom publik tetap; migration 003 membuat view security_invoker dan mencabut akses langsung anon/authenticated.
- [done] Skrip cek akses publik tanpa mencetak key atau isi ulasan.
- [done] Production build termasuk pemeriksaan TypeScript/lint bawaan Next lolos; sintaks skrip valid. .env.local dan .env.rls-test tetap diabaikan git.
- [done] Laporan docs/public-reviews-result.json terbaru passed: RPC publik tersedia, akses anonim langsung reviews/public_reviews ditolak. Laporan diperiksa pada sesi ini.
- [todo] Uji kepemilikan ulasan dengan dua akun. Label UNRESTRICTED pada view bukan hasil pengujian RLS tabel.

## Riwayat pekerjaan sebelumnya
- [done] Phase 1: fondasi + token + demo lokal kosong, landing dengan contoh berlabel
- [done] Auth dan onboarding: Supabase client, register/login/logout/reset/konfirmasi
- [done] Dashboard dan logika keuangan: saldo, aman dibelanjakan, rata-rata 3 bulan
- [done] Transactions CRUD dan filter: nominal/tanggal/kategori, modal Radix
- [done] Budget dan goals CRUD: per bulan, warning, proyeksi nol/tercapai
- [done] Edit profil dan permintaan perubahan email/password
- [done] .env.local dibuat tanpa overwrite, gitignored; /setup cek Auth/database tanpa menampilkan key
- [done] Migration, setup, verifikasi lokal; integrasi live memerlukan Supabase
- [todo] Phase 2 (belum dimulai)
- [todo] Phase 3 (belum dimulai)

Keputusan: repo kosong. Demo lokal eksplisit saat env Supabase belum tersedia.
Masalah terbuka: akses Supabase, QRIS, hosting belum tersedia.
Logo resmi sudah diberikan dan dipasang; navbar landing memakai blue-100.
- [done] Logo terpusat dan icon tab dari file asli pengguna
- [done] Ulasan pengguna: rating, filter, edit/hapus, persistence demo/Supabase; migration 002
Verifikasi ulasan: typecheck dan build lolos; browser demo simpan/edit rating/filter dan persetujuan wajib lolos. Environment Supabase telah terisi oleh pengguna; tabel ulasan belum dapat diakses. Migration 002 dan uji live RLS ulasan masih perlu dijalankan.
Browser ulasan 375/768/1280px: tidak ada overflow; persistence reload dan hapus demo teruji. Bukti visual docs/reviews-demo.jpg (data pengujian berlabel demo, telah dihapus dari browser).
Verifikasi final logo/ulasan: production build termasuk TypeScript lolos; favicon /icon.png dan tiga instance logo termuat. Landing 375/768/1280 tanpa overflow. File logo dan favicon identik dengan file asli pengguna (hash cocok). Dua commit fitur disimpan; .env.local tetap tidak tracked.
Langkah berikutnya untuk ulasan publik: jalankan 002_reviews.sql pada Supabase SQL Editor, lalu uji dua akun. Ulasan demo di /reviews?demo=1 tidak pernah dipublikasikan otomatis.
Optimistic update transaksi dengan rollback saat server gagal; animasi nominal 350ms menghormati reduced motion.
Kategori awal tetap, tanpa batas jumlah transaksi/goals Phase 1; batas Free ditetapkan di Phase 2.
Vercel Hobby nonkomersial saja menurut dokumentasi; jangan deploy penawaran berbayar di Hobby.
Tema disesuaikan sesuai instruksi terbaru: putih + biru 50–900, hijau hanya pemasukan/sukses.
Verifikasi final: 8 unit test finance lolos; typecheck lolos; production build lolos; npm audit 0 vulnerabilities setelah override PostCSS.
Browser: onboarding demo, income Rp20.000, expense Rp5.000, target alokasi Rp10.000 teruji; saldo tidak berkurang oleh target. Ditemukan checkbox budget wajib diterima sebagai boolean oleh react-hook-form; diperbaiki.
Mobile 375px: kelima halaman tanpa horizontal overflow. Navigasi icon-only tablet ditemukan kehilangan nama aksesibel; ditambah aria-label/title.
375/768/1280px: kelima halaman tanpa horizontal overflow. CRUD transaksi + search/filter, edit profil, CRUD budget/target, budget wajib, target alokasi nol dan target tercapai diuji via browser demo. /setup dengan env kosong menunjukkan instruksi dan tidak memaparkan key. Data pengujian demo dibersihkan setelah selesai.
Belum teruji live: email konfirmasi/reset, RLS dua akun, migration PostgreSQL. Premium/admin/pembayaran belum diimplementasikan (Phase 2), sehingga belum dapat diuji.
Phase 1 MVP lokal selesai. Tidak lanjut otomatis ke Phase 2.
Langkah berikutnya: pengguna isi dua variabel publik di .env.local, jalankan migration SQL di Supabase, restart dev, cek /setup, lalu uji register/konfirmasi/reset dan isolasi dua akun. Phase 2 hanya setelah diminta.
