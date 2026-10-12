begin;
create table public.finance_preferences (
 user_id uuid primary key references auth.users(id) on delete cascade,
 report_range_months integer not null default 3 check(report_range_months in (3,6)),
 default_rounding integer not null default 0 check(default_rounding in (0,100,500,1000))
);
alter table public.finance_preferences enable row level security;
revoke all on public.finance_preferences from public,anon,authenticated;
grant select on public.finance_preferences to authenticated;
create policy own_finance_preferences on public.finance_preferences for select to authenticated using(user_id=auth.uid());
insert into public.finance_preferences(user_id) select id from auth.users on conflict do nothing;
create function public.get_finance_preferences() returns public.finance_preferences language plpgsql security definer set search_path='' as $$
declare p public.finance_preferences;begin
 if auth.uid() is null then raise exception 'Login diperlukan' using errcode='42501';end if;
 insert into public.finance_preferences(user_id) values(auth.uid()) on conflict do nothing;
 select * into p from public.finance_preferences where user_id=auth.uid();return p;
end $$;
create function public.set_default_rounding(p_step integer) returns void language plpgsql security definer set search_path='' as $$begin
 if auth.uid() is null then raise exception 'Login diperlukan' using errcode='42501';end if;
 if p_step is null or p_step not in (0,100,500,1000) then raise exception 'Pembulatan tidak valid' using errcode='22023';end if;
 insert into public.finance_preferences(user_id,default_rounding) values(auth.uid(),p_step) on conflict(user_id) do update set default_rounding=excluded.default_rounding;
end $$;
create function public.admin_set_report_range(p_user_id uuid,p_months integer) returns void language plpgsql security definer set search_path='' as $$
declare old_range integer;begin
 if not public.is_admin() then raise exception 'Akses ditolak' using errcode='42501';end if;
 if p_months is null or p_months not in (3,6) then raise exception 'Rentang hanya 3 atau 6 bulan' using errcode='22023';end if;
 select report_range_months into old_range from public.finance_preferences where user_id=p_user_id;
 insert into public.finance_preferences(user_id,report_range_months) values(p_user_id,p_months) on conflict(user_id) do update set report_range_months=excluded.report_range_months;
 insert into public.audit_logs(admin_id,action,object_id,before_data,after_data) values(auth.uid(),'report.range',p_user_id::text,jsonb_build_object('months',old_range),jsonb_build_object('months',p_months));
end $$;
revoke all on function public.get_finance_preferences(),public.set_default_rounding(integer),public.admin_set_report_range(uuid,integer) from public,anon;
grant execute on function public.get_finance_preferences(),public.set_default_rounding(integer),public.admin_set_report_range(uuid,integer) to authenticated;

alter table public.transactions add column amount_original bigint;
alter table public.transactions add column amount_rounded bigint;
alter table public.transactions add column rounding_difference bigint;
alter table public.transactions add column rounding_step integer not null default 0 check(rounding_step in (0,100,500,1000));
alter table public.transactions add column receipt_path text;
-- Backfill columns only: existing quota trigger requires owner JWT, so temporarily disable
-- that trigger inside this transaction while the owner migrates unchanged historical amounts.
alter table public.transactions disable trigger enforce_transactions_plan;
update public.transactions set amount_original=(data->>'amount')::bigint,amount_rounded=(data->>'amount')::bigint,rounding_difference=0;
alter table public.transactions enable trigger enforce_transactions_plan;
alter table public.transactions alter column amount_original set not null;
alter table public.transactions alter column amount_rounded set not null;
alter table public.transactions alter column rounding_difference set not null;
alter table public.transactions add constraint rounding_audit_valid check(amount_original between 1 and 1000000000000 and amount_rounded between 1 and 1000000000000 and rounding_difference=amount_rounded-amount_original and rounding_difference>=0);

create table public.receipt_files (
 path text primary key,user_id uuid not null references auth.users(id) on delete cascade,
 transaction_id uuid not null,delete_after timestamptz not null default now()+interval '1 day',retiring boolean not null default false,
 check(path ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}/[0-9a-f-]{36}\.(jpg|png|webp)$' and split_part(path,'/',1)=user_id::text and split_part(path,'/',2)=transaction_id::text)
);
alter table public.receipt_files enable row level security;
revoke all on public.receipt_files from public,anon,authenticated;
grant select,insert(path,user_id,transaction_id) on public.receipt_files to authenticated;
create policy own_receipt_metadata on public.receipt_files for select to authenticated using(user_id=auth.uid());
create policy register_receipt on public.receipt_files for insert to authenticated with check(user_id=auth.uid() and exists(select 1 from public.transactions t where t.id=transaction_id and t.user_id=auth.uid() and t.data->>'type'='expense') and split_part(path,'/',1)=auth.uid()::text and split_part(path,'/',2)=transaction_id::text);
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('receipts','receipts',false,2097152,array['image/jpeg','image/png','image/webp']) on conflict(id) do update set public=false,file_size_limit=2097152,allowed_mime_types=excluded.allowed_mime_types;
create policy receipt_read on storage.objects for select to authenticated using(bucket_id='receipts' and (storage.foldername(name))[1]=auth.uid()::text);
create policy receipt_insert on storage.objects for insert to authenticated with check(bucket_id='receipts' and (storage.foldername(name))[1]=auth.uid()::text and exists(select 1 from public.receipt_files f where f.path=name and f.user_id=auth.uid() and not f.retiring));
create policy receipt_delete on storage.objects for delete to authenticated using(bucket_id='receipts' and (storage.foldername(name))[1]=auth.uid()::text);
-- Replacements use a fresh immutable object path; overwrite of an attached object is forbidden.
create function public.normalize_transaction() returns trigger language plpgsql security definer set search_path='' as $$
declare original numeric;step integer;rounded numeric;p text;f public.receipt_files;
begin
 if auth.uid() is null or new.user_id<>auth.uid() then raise exception 'Akses ditolak' using errcode='42501';end if;
 original:=coalesce((new.data->>'amount_original')::numeric,(new.data->>'amount')::numeric);step:=coalesce((new.data->>'rounding_step')::integer,0);
 if original is null or original<>trunc(original) or original not between 1 and 1000000000000 or step not in (0,100,500,1000) then raise exception 'Nominal/pembulatan tidak valid' using errcode='22023';end if;
 rounded:=case when step=0 then original else ceil(original/step)*step end;
 if rounded>1000000000000 then raise exception 'Nominal hasil pembulatan terlalu besar' using errcode='22023';end if;
 p:=nullif(new.data->>'receipt_path','');
 if p is not null then
  if new.data->>'type'<>'expense' then raise exception 'Struk hanya untuk pengeluaran' using errcode='22023';end if;
  select * into f from public.receipt_files where path=p and user_id=auth.uid() and transaction_id=new.id and not retiring for update;
  if not found or not exists(select 1 from storage.objects where bucket_id='receipts' and name=p and metadata->>'mimetype' in ('image/jpeg','image/png','image/webp') and (metadata->>'size')::bigint between 1 and 2097152) then raise exception 'Struk tidak valid atau bukan milikmu' using errcode='42501';end if;
 end if;
 new.amount_original:=original;new.amount_rounded:=rounded;new.rounding_step:=step;new.rounding_difference:=rounded-original;new.receipt_path:=p;
 new.data:=new.data||jsonb_build_object('amount',rounded,'amount_original',original,'amount_rounded',rounded,'rounding_step',step,'rounding_difference',rounded-original,'receipt_path',p);
 return new;
end $$;
create trigger normalize_transaction before insert or update on public.transactions for each row execute function public.normalize_transaction();
create function public.retire_old_receipt() returns trigger language plpgsql security definer set search_path='' as $$begin
 if tg_op='DELETE' then if old.receipt_path is not null then update public.receipt_files set delete_after=now() where path=old.receipt_path;end if;return old;end if;
 if old.receipt_path is not null and old.receipt_path is distinct from new.receipt_path then update public.receipt_files set delete_after=now() where path=old.receipt_path;end if;
 return new;
end $$;
create trigger retire_old_receipt after update or delete on public.transactions for each row execute function public.retire_old_receipt();
create function public.claim_receipt_cleanup() returns setof text language plpgsql security definer set search_path='' as $$
declare f public.receipt_files;begin
 if auth.uid() is null then raise exception 'Login diperlukan' using errcode='42501';end if;
 for f in select * from public.receipt_files where user_id=auth.uid() and delete_after<=now() order by path limit 100 for update skip locked loop
  if not exists(select 1 from public.transactions where user_id=auth.uid() and receipt_path=f.path) then update public.receipt_files set retiring=true where path=f.path;return next f.path;end if;
 end loop;
end $$;
create function public.ack_receipt_cleanup(p_path text) returns void language plpgsql security definer set search_path='' as $$begin
 if auth.uid() is null then raise exception 'Login diperlukan' using errcode='42501';end if;
 delete from public.receipt_files where user_id=auth.uid() and path=p_path and retiring and not exists(select 1 from storage.objects where bucket_id='receipts' and name=p_path);
end $$;
revoke all on function public.normalize_transaction(),public.retire_old_receipt(),public.claim_receipt_cleanup(),public.ack_receipt_cleanup(text) from public,anon;
grant execute on function public.claim_receipt_cleanup(),public.ack_receipt_cleanup(text) to authenticated;
notify pgrst,'reload schema';
commit;
