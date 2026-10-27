begin;

-- Harga baru berlaku untuk katalog dan paket. Snapshot order yang sudah dibuat tetap.
update public.plans set price_rupiah=9000 where code='plus';
update public.plans set price_rupiah=19000 where code='pro';
update public.products set price_rupiah=9000 where code='plus-30';
update public.products set price_rupiah=19000 where code='pro-30';

notify pgrst,'reload schema';
commit;
