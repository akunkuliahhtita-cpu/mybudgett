-- SQL Editor verification after migrations 018 and 019. Uses only fresh fictional accounts; rollback is mandatory.
begin;
create function pg_temp.assert_true(ok boolean,label text) returns void language plpgsql as $$begin if ok is distinct from true then raise exception 'FAIL: %',label;end if;end$$;
create function pg_temp.denied(q text) returns boolean language plpgsql as $$begin execute q;return false;exception when insufficient_privilege or invalid_parameter_value then return true;end$$;
create function pg_temp.rejects_null(q text) returns boolean language plpgsql as $$begin execute q;return false;exception when sqlstate 'P0001' then return true;end$$;
select set_config('test.a',gen_random_uuid()::text,true),set_config('test.b',gen_random_uuid()::text,true),set_config('test.admin',gen_random_uuid()::text,true),set_config('test.ta',gen_random_uuid()::text,true),set_config('test.tb',gen_random_uuid()::text,true),set_config('test.tnull',gen_random_uuid()::text,true),set_config('test.ra',gen_random_uuid()::text,true),set_config('test.rb',gen_random_uuid()::text,true),set_config('test.rnew',gen_random_uuid()::text,true);
insert into auth.users(id,instance_id,aud,role,email,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
select id,'00000000-0000-0000-0000-000000000000'::uuid,'authenticated','authenticated',id::text||'@example.invalid',now(),'{"provider":"email","providers":["email"]}','{}',now(),now()
from (values(current_setting('test.a')::uuid),(current_setting('test.b')::uuid),(current_setting('test.admin')::uuid)) f(id);
insert into public.admin_users(user_id) values(current_setting('test.admin')::uuid);
update public.subscriptions set plan='plus',status='active',expires_at=now()+interval '90 days' where user_id=current_setting('test.a')::uuid;

set local role authenticated;
select set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('test.a'),'role','authenticated')::text,true);
select public.get_finance_preferences();
select pg_temp.assert_true((select report_range_months=3 and default_rounding=0 from public.finance_preferences where user_id=auth.uid()),'default range 3 and rounding none');
select public.set_default_rounding(500);
select pg_temp.assert_true((select default_rounding=500 from public.finance_preferences where user_id=auth.uid()),'rounding preference saves');
select pg_temp.assert_true(pg_temp.denied('select public.set_default_rounding(250)'),'rounding only allows 0/100/500/1000');
select pg_temp.assert_true(pg_temp.denied('update public.finance_preferences set report_range_months=6 where user_id=auth.uid()'),'user cannot edit report range directly');
insert into public.transactions(id,user_id,data) values(current_setting('test.ta')::uuid,auth.uid(),jsonb_build_object('amount',1021,'amount_original',1021,'rounding_step',100,'type','expense','category','Makan & minum','description','Test receipt A','date',(now() at time zone 'Asia/Jakarta')::date::text));
select pg_temp.assert_true((select amount_original=1021 and amount_rounded=1100 and rounding_difference=79 and data->>'amount'='1100' from public.transactions where id=current_setting('test.ta')::uuid),'database rounds up and preserves audit amounts');
select pg_temp.assert_true(pg_temp.rejects_null(format($q$insert into public.transactions(id,user_id,data) values(%L::uuid,auth.uid(),jsonb_build_object('amount',500,'type','expense','category','Makan & minum','description','Null rejection test','date',(now() at time zone 'Asia/Jakarta')::date::text,'unexpected_optional_field',null))$q$,current_setting('test.tnull')),'transaction JSON null is rejected by the finance trigger');
insert into public.receipt_files(path,user_id,transaction_id) values(current_setting('test.a')||'/'||current_setting('test.ta')||'/'||current_setting('test.ra')||'.webp',auth.uid(),current_setting('test.ta')::uuid);
select set_config('test.patha',current_setting('test.a')||'/'||current_setting('test.ta')||'/'||current_setting('test.ra')||'.webp',true);
select pg_temp.assert_true(pg_temp.denied(format('insert into public.receipt_files(path,user_id,transaction_id) values(%L,%L::uuid,%L::uuid)',current_setting('test.b')||'/'||current_setting('test.tb')||'/'||current_setting('test.rb')||'.webp',current_setting('test.b'),current_setting('test.tb'))),'cannot register receipt without owned expense');
reset role;
insert into storage.objects(bucket_id,name,metadata) values('receipts',current_setting('test.patha'),'{"mimetype":"image/webp","size":100}');

set local role authenticated;
select set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('test.b'),'role','authenticated')::text,true);
insert into public.transactions(id,user_id,data) values(current_setting('test.tb')::uuid,auth.uid(),jsonb_build_object('amount',2000,'type','expense','category','Makan & minum','description','Test receipt B','date',(now() at time zone 'Asia/Jakarta')::date::text));
insert into public.receipt_files(path,user_id,transaction_id) values(current_setting('test.b')||'/'||current_setting('test.tb')||'/'||current_setting('test.rb')||'.webp',auth.uid(),current_setting('test.tb')::uuid);
select set_config('test.pathb',current_setting('test.b')||'/'||current_setting('test.tb')||'/'||current_setting('test.rb')||'.webp',true);
reset role;
insert into storage.objects(bucket_id,name,metadata) values('receipts',current_setting('test.pathb'),'{"mimetype":"image/webp","size":100}');

set local role authenticated;
select set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('test.a'),'role','authenticated')::text,true);
select pg_temp.assert_true((select count(*)=0 from public.transactions where user_id=current_setting('test.b')::uuid),'A cannot read B transactions');
select pg_temp.assert_true((select count(*)=0 from public.receipt_files where user_id=current_setting('test.b')::uuid),'A cannot read B receipt metadata');
select pg_temp.assert_true((select count(*)=0 from storage.objects where bucket_id='receipts' and name=current_setting('test.pathb')),'A cannot read B private receipt object');
select pg_temp.assert_true((select not public from storage.buckets where id='receipts'),'receipt bucket is private');
select set_config('test.old_month',(date_trunc('month',now() at time zone 'Asia/Jakarta')-interval '3 months')::date::text,true);
select pg_temp.assert_true(pg_temp.denied(format('select public.assert_report_window(%L::date,%L::date)',current_setting('test.old_month'),current_setting('test.old_month'))),'three-month window rejects older month');
reset role;

set local role authenticated;
select set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('test.admin'),'role','authenticated')::text,true);
select public.admin_set_report_range(current_setting('test.a')::uuid,6);
select pg_temp.assert_true(pg_temp.denied(format('select public.admin_set_report_range(%L::uuid,4)',current_setting('test.a'))),'range accepts only 3 or 6');
reset role;
set local role authenticated;
select set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('test.a'),'role','authenticated')::text,true);
select pg_temp.assert_true((public.get_monthly_report()->>'range')::integer=6,'monthly report honors admin six-month range');
select pg_temp.assert_true(jsonb_array_length(public.get_monthly_report()->'transactions')=1,'report RPC returns only caller transactions');
reset role;
set local role authenticated;
select set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('test.admin'),'role','authenticated')::text,true);
select public.admin_set_report_range(current_setting('test.a')::uuid,3);
select pg_temp.assert_true((select report_range_months=3 from public.finance_preferences where user_id=current_setting('test.a')::uuid),'admin range restored to 3');
reset role;

-- A replaces its receipt; old object and metadata are removed by the cleanup RPC.
set local role authenticated;
select set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('test.a'),'role','authenticated')::text,true);
insert into public.receipt_files(path,user_id,transaction_id) values(current_setting('test.a')||'/'||current_setting('test.ta')||'/'||current_setting('test.rnew')||'.webp',auth.uid(),current_setting('test.ta')::uuid);
select set_config('test.pathnew',current_setting('test.a')||'/'||current_setting('test.ta')||'/'||current_setting('test.rnew')||'.webp',true);
reset role;
insert into storage.objects(bucket_id,name,metadata) values('receipts',current_setting('test.pathnew'),'{"mimetype":"image/webp","size":100}');
set local role authenticated;
select set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('test.a'),'role','authenticated')::text,true);
update public.transactions set data=data||jsonb_build_object('receipt_path',current_setting('test.pathnew')) where id=current_setting('test.ta')::uuid;
select pg_temp.assert_true((select delete_after<=now() from public.receipt_files where path=current_setting('test.patha')),'replaced receipt is queued for deletion');
select set_config('test.cleanup',current_setting('test.patha'),true);
select pg_temp.assert_true(exists(select 1 from public.claim_receipt_cleanup() as claimed(path) where claimed.path=current_setting('test.cleanup')),'cleanup claims old receipt');
delete from storage.objects where bucket_id='receipts' and name=current_setting('test.cleanup');
select public.ack_receipt_cleanup(current_setting('test.cleanup'));
select pg_temp.assert_true(not exists(select 1 from public.receipt_files where path=current_setting('test.cleanup')),'old receipt metadata removed after storage deletion');
delete from public.transactions where id=current_setting('test.ta')::uuid;
select pg_temp.assert_true(exists(select 1 from public.claim_receipt_cleanup() as claimed(path) where claimed.path=current_setting('test.pathnew')),'deleted transaction receipt is queued');
select 'PASS: rounding audit, 3/6 month limit, owner RLS, private receipts and deletion cleanup; ROLLBACK removes fixtures' as result;
rollback;
