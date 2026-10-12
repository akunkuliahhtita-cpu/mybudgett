begin;

-- reject_null_finance_fields() intentionally rejects every JSONB null value.
-- Keep receipt_path absent when there is no receipt instead of serializing null.
create or replace function public.normalize_transaction()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
declare
 original numeric;
 step integer;
 rounded numeric;
 p text;
 f public.receipt_files;
begin
 if auth.uid() is null or new.user_id<>auth.uid() then
  raise exception 'Akses ditolak' using errcode='42501';
 end if;

 original:=coalesce((new.data->>'amount_original')::numeric,(new.data->>'amount')::numeric);
 step:=coalesce((new.data->>'rounding_step')::integer,0);
 if original is null or original<>trunc(original) or original not between 1 and 1000000000000 or step not in (0,100,500,1000) then
  raise exception 'Nominal/pembulatan tidak valid' using errcode='22023';
 end if;
 rounded:=case when step=0 then original else ceil(original/step)*step end;
 if rounded>1000000000000 then raise exception 'Nominal hasil pembulatan terlalu besar' using errcode='22023'; end if;

 p:=nullif(new.data->>'receipt_path','');
 if p is not null then
  if new.data->>'type'<>'expense' then raise exception 'Struk hanya untuk pengeluaran' using errcode='22023'; end if;
  select * into f from public.receipt_files where path=p and user_id=auth.uid() and transaction_id=new.id and not retiring for update;
  if not found or not exists(select 1 from storage.objects where bucket_id='receipts' and name=p and metadata->>'mimetype' in ('image/jpeg','image/png','image/webp') and (metadata->>'size')::bigint between 1 and 2097152) then
   raise exception 'Struk tidak valid atau bukan milikmu' using errcode='42501';
  end if;
 end if;

 new.amount_original:=original;
 new.amount_rounded:=rounded;
 new.rounding_step:=step;
 new.rounding_difference:=rounded-original;
 new.receipt_path:=p;
 new.data:=new.data||jsonb_build_object('amount',rounded,'amount_original',original,'amount_rounded',rounded,'rounding_step',step,'rounding_difference',rounded-original);
 if p is null then
  new.data:=new.data-'receipt_path';
 else
  new.data:=new.data||jsonb_build_object('receipt_path',p);
 end if;
 return new;
end $$;

notify pgrst,'reload schema';
commit;
