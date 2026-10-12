begin;

-- Repair existing bucket records too; do not rely on first-install state.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('receipts','receipts',false,2097152,array['image/jpeg','image/png','image/webp'])
on conflict(id) do update
 set public=false,
     file_size_limit=excluded.file_size_limit,
     allowed_mime_types=excluded.allowed_mime_types;

-- Reassert the owner-folder policies. Receipts are immutable objects, so there
-- is intentionally no UPDATE policy; replacing a receipt uses a new path.
drop policy if exists receipt_read on storage.objects;
create policy receipt_read on storage.objects
 for select to authenticated
 using(bucket_id='receipts' and (storage.foldername(name))[1]=auth.uid()::text);

drop policy if exists receipt_insert on storage.objects;
create policy receipt_insert on storage.objects
 for insert to authenticated
 with check(bucket_id='receipts'
  and (storage.foldername(name))[1]=auth.uid()::text
  and exists(select 1 from public.receipt_files f
   where f.path=name and f.user_id=auth.uid() and not f.retiring));

drop policy if exists receipt_delete on storage.objects;
create policy receipt_delete on storage.objects
 for delete to authenticated
 using(bucket_id='receipts' and (storage.foldername(name))[1]=auth.uid()::text);

-- Restrictive guard also blocks any other permissive policy from widening
-- receipt access to another user's folder.
drop policy if exists receipt_owner_guard on storage.objects;
create policy receipt_owner_guard on storage.objects
 as restrictive for all to public
 using(bucket_id<>'receipts' or (storage.foldername(name))[1]=auth.uid()::text)
 with check(bucket_id<>'receipts' or (storage.foldername(name))[1]=auth.uid()::text);

notify pgrst,'reload schema';
commit;
