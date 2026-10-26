-- Jalankan manual di SQL Editor sebagai pemilik project, setelah schema_baru.sql.
-- Daftarkan akun di Supabase Auth dan konfirmasi email terlebih dahulu.
-- Pengaturan ini hanya memberi role admin; tidak mengaktifkan paket atau pembayaran.
begin;
do $$
declare target_id uuid; matches bigint; confirmed boolean;
begin
 if to_regclass('public.admin_users') is null then
  raise exception 'Jalankan schema_baru.sql terlebih dahulu.';
 end if;
 select count(*),(array_agg(id))[1],bool_and(email_confirmed_at is not null)
 into matches,target_id,confirmed from auth.users
 where lower(email)=lower('leufayyproduction@gmail.com');
 if matches<>1 then
  raise exception 'Harus ada tepat satu akun leufayyproduction@gmail.com. Daftarkan akun dahulu.';
 end if;
 if confirmed is distinct from true then
  raise exception 'Konfirmasi email akun admin terlebih dahulu.';
 end if;
 insert into public.admin_users(user_id) values(target_id) on conflict(user_id) do nothing;
end $$;
commit;
select 'Akun admin tersimpan. Masuk melalui /admin/login.' as result;
