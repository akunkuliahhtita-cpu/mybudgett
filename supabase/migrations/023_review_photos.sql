begin;

-- Private image objects; public reads are allowed only through RLS for approved reviews.
create table public.review_photos (
 id uuid primary key default gen_random_uuid(),
 review_id uuid not null references public.reviews(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 path text not null unique,
 mime_type text not null check (mime_type in ('image/webp','image/jpeg','image/png')),
 size_bytes integer not null check (size_bytes between 1 and 299999),
 created_at timestamptz not null default now(),
 check(path ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}/[a-zA-Z0-9_-]+\.webp$' or path ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}/[a-zA-Z0-9_-]+\.(jpg|png)$')
);
create index review_photos_review on public.review_photos(review_id,created_at);
alter table public.review_photos enable row level security;
revoke all on public.review_photos from public,anon,authenticated;
grant select,insert,delete on public.review_photos to authenticated;
create policy review_photo_owner_read on public.review_photos for select to authenticated
 using(user_id=auth.uid() and exists(select 1 from public.reviews r where r.id=review_id and r.user_id=auth.uid()));
create policy review_photo_owner_insert on public.review_photos for insert to authenticated
 with check(user_id=auth.uid() and exists(select 1 from public.reviews r where r.id=review_id and r.user_id=auth.uid() and r.status='pending')
  and exists(select 1 from storage.objects o where o.bucket_id='review-photos' and o.name=path
   and o.metadata->>'mimetype'=mime_type and (o.metadata->>'size')::integer=size_bytes));
create policy review_photo_owner_delete on public.review_photos for delete to authenticated
 using(user_id=auth.uid() and exists(select 1 from public.reviews r where r.id=review_id and r.user_id=auth.uid()));
create policy review_photo_admin_read on public.review_photos for select to authenticated using(public.is_admin());

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('review-photos','review-photos',false,300000,array['image/webp','image/jpeg','image/png'])
on conflict(id) do update set public=false,file_size_limit=300000,allowed_mime_types=excluded.allowed_mime_types;

create or replace function public.can_upload_review_photo(p_name text,p_mime text,p_size bigint)
returns boolean language plpgsql volatile security definer set search_path='' as $$
declare review_key text;
begin
 if auth.uid() is null or p_mime not in ('image/webp','image/jpeg','image/png') or p_size is null or p_size not between 1 and 299999
  or p_name !~ '^[0-9a-f-]{36}/[0-9a-f-]{36}/[a-zA-Z0-9_-]+\.(webp|jpg|png)$'
  or split_part(p_name,'/',1)<>auth.uid()::text then return false;end if;
 review_key:=split_part(p_name,'/',2);
 perform pg_advisory_xact_lock(hashtextextended(review_key,230));
 return exists(select 1 from public.reviews r where r.id::text=review_key and r.user_id=auth.uid() and r.status='pending')
  and (select count(*) from storage.objects o where o.bucket_id='review-photos' and split_part(o.name,'/',2)=review_key)<3;
end;
$$;
revoke all on function public.can_upload_review_photo(text,text,bigint) from public,anon;
grant execute on function public.can_upload_review_photo(text,text,bigint) to authenticated;

create or replace function public.can_read_approved_review_photo(p_name text)
returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.review_photos p join public.reviews r on r.id=p.review_id
  where p.path=p_name and r.status='approved');
$$;
revoke all on function public.can_read_approved_review_photo(text) from public;
grant execute on function public.can_read_approved_review_photo(text) to anon,authenticated;

create policy review_photo_upload on storage.objects for insert to authenticated
 with check(bucket_id='review-photos' and public.can_upload_review_photo(name,metadata->>'mimetype',(metadata->>'size')::bigint));
create policy review_photo_public_approved on storage.objects for select to anon,authenticated
 using(bucket_id='review-photos' and public.can_read_approved_review_photo(name));
create policy review_photo_owner_read on storage.objects for select to authenticated
 using(bucket_id='review-photos' and split_part(name,'/',1)=auth.uid()::text and exists(
  select 1 from public.reviews r where r.id::text=split_part(name,'/',2) and r.user_id=auth.uid()));
create policy review_photo_admin_pending on storage.objects for select to authenticated
 using(bucket_id='review-photos' and public.is_admin());
create policy review_photo_owner_delete on storage.objects for delete to authenticated
 using(bucket_id='review-photos' and split_part(name,'/',1)=auth.uid()::text);
create policy review_photo_admin_delete on storage.objects for delete to authenticated
 using(bucket_id='review-photos' and public.is_admin());

-- Refuse direct RPC deletion while any Storage object remains; the admin API removes
-- the objects first, then invokes the existing moderation RPC.
create or replace function public.moderate_review(p_id uuid,p_action text) returns void
language plpgsql security definer set search_path='' as $$
declare r public.reviews;
begin
 if not public.is_admin() then raise exception 'Akses ditolak.' using errcode='42501';end if;
 if p_action not in ('approved','hidden','delete') or p_action is null then raise exception 'Aksi tidak valid.' using errcode='22023';end if;
 select * into r from public.reviews where id=p_id for update;
 if not found then raise exception 'Ulasan tidak ditemukan.' using errcode='22023';end if;
 if p_action='approved' and (r.order_id is null or not exists(select 1 from public.orders where id=r.order_id and user_id=r.user_id and product_id=r.product_id and status='paid')) then raise exception 'Ulasan tidak terhubung ke pembelian terverifikasi.' using errcode='22023';end if;
 if p_action='delete' then
  if exists(select 1 from storage.objects where bucket_id='review-photos' and split_part(name,'/',2)=p_id::text) then raise exception 'Hapus semua foto Storage melalui halaman admin terlebih dahulu.' using errcode='P0001';end if;
  delete from public.reviews where id=p_id;
 else update public.reviews set status=p_action where id=p_id;end if;
 insert into public.audit_logs(admin_id,action,object_id,before_data,after_data) values(auth.uid(),'review.'||p_action,p_id::text,to_jsonb(r),jsonb_build_object('status',p_action));
end $$;
revoke all on function public.moderate_review(uuid,text) from public,anon;
grant execute on function public.moderate_review(uuid,text) to authenticated;

create or replace function public.get_public_review_photos(p_review_ids uuid[])
returns table(review_id uuid,path text) language sql stable security definer set search_path='' as $$
 select p.review_id,p.path from public.review_photos p join public.reviews r on r.id=p.review_id
 where p.review_id=any(coalesce(p_review_ids,array[]::uuid[])) and r.status='approved'
 order by p.created_at,p.id;
$$;
revoke all on function public.get_public_review_photos(uuid[]) from public;
grant execute on function public.get_public_review_photos(uuid[]) to anon,authenticated;

notify pgrst,'reload schema';
commit;


