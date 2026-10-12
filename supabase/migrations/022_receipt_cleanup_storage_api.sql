begin;

-- Storage objects must be removed through the Supabase Storage API. This RPC
-- acknowledges a successful API removal by deleting only the owner's metadata.
create or replace function public.ack_receipt_cleanup(p_path text)
returns void
language plpgsql
security definer
set search_path=''
as $$
begin
 if auth.uid() is null then
  raise exception 'Login diperlukan' using errcode='42501';
 end if;

 delete from public.receipt_files
 where user_id=auth.uid()
  and path=p_path
  and retiring
  and not exists(
   select 1 from public.transactions
   where user_id=auth.uid() and receipt_path=p_path
  );
end;
$$;

revoke all on function public.ack_receipt_cleanup(text) from public,anon;
grant execute on function public.ack_receipt_cleanup(text) to authenticated;

notify pgrst,'reload schema';
commit;
