-- My Budget: consolidated fresh-project schema, migrations 001–022.
-- Run once in Supabase SQL Editor on an empty project with standard Supabase schemas (auth, storage) enabled.
-- Contains application routines that delete records only when explicitly invoked by application/admin actions.
-- Does not drop/truncate data or seed demo/user data. Catalog rows and plan definitions are product configuration.


-- ===== supabase/migrations/001_phase1.sql =====
-- Phase 1. No premium/admin fields are user editable. All values are integer rupiah.
create table if not exists public.profiles (
 user_id uuid primary key references auth.users(id) on delete cascade,
 data jsonb not null,
 constraint profile_valid check (jsonb_typeof(data->'name')='string' and length(data->>'name') between 1 and 60
 and data->>'pattern' in ('Penghasilan tetap','Freelance/tidak tetap','Campuran')
 and data->>'purpose' in ('Mengatur pengeluaran','Menabung','Mengontrol budget','Mencapai target keuangan','Memahami kondisi keuangan')
 and (data->>'opening')::numeric between 0 and 1000000000000
 and (data->>'fixed')::numeric between 0 and 1000000000000
 and (data->>'project')::numeric between 0 and 1000000000000
 and (data->>'projects')::numeric between 0 and 1000
 and (data->>'opening')::numeric=trunc((data->>'opening')::numeric)
 and (data->>'fixed')::numeric=trunc((data->>'fixed')::numeric)
 and (data->>'project')::numeric=trunc((data->>'project')::numeric)
 and (data->>'projects')::numeric=trunc((data->>'projects')::numeric)),
 constraint profile_required check (data ?& array['name','pattern','purpose','opening','fixed','project','projects'])
);
create table if not exists public.categories (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade,
 name text not null check (length(name) between 1 and 60), unique(user_id,name), unique(id,user_id)
);
create table if not exists public.transactions (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade,
 data jsonb not null, category_id uuid,
 foreign key (category_id,user_id) references public.categories(id,user_id),
 constraint transaction_required check (data ?& array['amount','type','category','description','date']),
 constraint transaction_valid check ((data->>'amount')::numeric between 1 and 1000000000000
 and (data->>'amount')::numeric=trunc((data->>'amount')::numeric)
 and data->>'type' in ('income','expense') and length(data->>'description')<=180
 and data->>'category' in ('Makan & minum','Transportasi','Belanja','Tagihan','Kesehatan','Hiburan','Lainnya','Project','Gaji')
 and data->>'date' ~ '^\d{4}-\d{2}-\d{2}$'
 and (data->>'date')::date<=(now() at time zone 'Asia/Jakarta')::date)
);
create table if not exists public.budgets (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade,
 data jsonb not null, category_id uuid,
 foreign key (category_id,user_id) references public.categories(id,user_id),
 constraint budget_required check (data ?& array['amount','category','month','mandatory']),
 constraint budget_valid check ((data->>'amount')::numeric between 1 and 1000000000000
 and (data->>'amount')::numeric=trunc((data->>'amount')::numeric)
 and data->>'month' ~ '^\d{4}-(0[1-9]|1[0-2])$' and jsonb_typeof(data->'mandatory')='boolean'
 and data->>'category' in ('Makan & minum','Transportasi','Belanja','Tagihan','Kesehatan','Hiburan','Lainnya'))
);
create unique index if not exists budget_category_month on public.budgets(user_id,(data->>'category'),(data->>'month'));
create table if not exists public.goals (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade,
 data jsonb not null,
 constraint goal_required check (data ?& array['name','target','saved','monthly']),
 constraint goal_valid check (length(data->>'name') between 1 and 80
 and (data->>'target')::numeric between 1 and 1000000000000
 and (data->>'saved')::numeric between 0 and 1000000000000
 and (data->>'monthly')::numeric between 0 and 1000000000000
 and (data->>'target')::numeric=trunc((data->>'target')::numeric)
 and (data->>'saved')::numeric=trunc((data->>'saved')::numeric)
 and (data->>'monthly')::numeric=trunc((data->>'monthly')::numeric))
);
alter table public.profiles enable row level security;
alter table public.categories enable row level security;
alter table public.transactions enable row level security;
alter table public.budgets enable row level security;
alter table public.goals enable row level security;
create policy own_profile on public.profiles for all to authenticated using ((select auth.uid())=user_id) with check ((select auth.uid())=user_id);
create policy own_categories on public.categories for all to authenticated using ((select auth.uid())=user_id) with check ((select auth.uid())=user_id);
create policy own_transactions on public.transactions for all to authenticated using ((select auth.uid())=user_id) with check ((select auth.uid())=user_id);
create policy own_budgets on public.budgets for all to authenticated using ((select auth.uid())=user_id) with check ((select auth.uid())=user_id);
create policy own_goals on public.goals for all to authenticated using ((select auth.uid())=user_id) with check ((select auth.uid())=user_id);
create index if not exists transactions_owner on public.transactions(user_id);
create index if not exists goals_owner on public.goals(user_id);
grant select,insert,update,delete on public.profiles,public.categories,public.transactions,public.budgets,public.goals to authenticated;
revoke all on public.profiles,public.categories,public.transactions,public.budgets,public.goals from anon;

-- SQL CHECK treats null as valid; reject JSON null values explicitly.
create function public.reject_null_finance_fields() returns trigger language plpgsql set search_path = '' as $$
begin
 if exists(select 1 from jsonb_each(new.data) as f where f.value='null'::jsonb) then
   raise exception 'Financial fields must not be null';
 end if;
 return new;
end $$;
create trigger profiles_no_null before insert or update on public.profiles for each row execute function public.reject_null_finance_fields();
create trigger transactions_no_null before insert or update on public.transactions for each row execute function public.reject_null_finance_fields();
create trigger budgets_no_null before insert or update on public.budgets for each row execute function public.reject_null_finance_fields();
create trigger goals_no_null before insert or update on public.goals for each row execute function public.reject_null_finance_fields();


-- ===== supabase/migrations/002_reviews.sql =====
-- Public, opt-in display name + review only. Private owner IDs stay behind RLS.
create table if not exists public.reviews (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references auth.users(id) on delete cascade,
 display_name text not null check (char_length(trim(display_name)) between 2 and 60),
 rating smallint not null check (rating between 1 and 5),
 body text not null check (char_length(trim(body)) between 10 and 1000),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
alter table public.reviews enable row level security;

revoke all on public.reviews from anon,authenticated;
grant select,delete on public.reviews to authenticated;
grant insert(user_id,display_name,rating,body),update(user_id,display_name,rating,body) on public.reviews to authenticated;
create function public.review_timestamps() returns trigger language plpgsql set search_path='' as $$
begin new.updated_at=now(); return new; end $$;
create trigger review_updated before update on public.reviews for each row execute function public.review_timestamps();
-- Deliberate owner-rights projection: only consented public fields, never user_id/email/profile.
create view public.public_reviews as select id,display_name,rating,body,created_at,updated_at from public.reviews;
grant select on public.public_reviews to anon,authenticated;
create function public.review_summary() returns table(total bigint,average numeric,counts bigint[])
language sql stable security definer set search_path='' as $$
 select count(*),coalesce(round(avg(rating),1),0),
 array[count(*) filter(where rating=1),count(*) filter(where rating=2),count(*) filter(where rating=3),count(*) filter(where rating=4),count(*) filter(where rating=5)]
 from public.reviews;
$$;
revoke all on function public.review_summary() from public;
grant execute on function public.review_summary() to anon,authenticated;


-- ===== supabase/migrations/003_secure_public_reviews.sql =====
-- Apply after 001 and 002. No data is deleted. Safe to run again.
begin;
alter view public.public_reviews set (security_invoker = true);
revoke all on public.public_reviews from public, anon, authenticated;
alter table public.reviews enable row level security;

-- Intentional public endpoint: fixed projection, no owner UUID/email/private profile.
create or replace function public.list_public_reviews(p_limit integer default 20)
returns table(id uuid,display_name text,rating smallint,body text,created_at timestamptz,updated_at timestamptz)
language sql stable security definer set search_path='' as $$
 select r.id,r.display_name,r.rating,r.body,r.created_at,r.updated_at
 from public.reviews r
 order by r.created_at desc,r.id desc
 limit least(100,greatest(1,coalesce(p_limit,20)));
$$;
revoke all on function public.list_public_reviews(integer) from public;
grant execute on function public.list_public_reviews(integer) to anon,authenticated;
notify pgrst, 'reload schema';
commit;


-- ===== supabase/migrations/004_plans_entitlements.sql =====
-- Packages only. No checkout, payment or user-editable subscription writes.
begin;
create table if not exists public.plans (
 code text primary key check (code in ('free','plus','pro')),
 name text not null,
 price_rupiah integer not null check (price_rupiah >= 0),
 duration_days integer,
 transactions_limit integer check (transactions_limit > 0),
 categories_limit integer check (categories_limit > 0),
 goals_limit integer check (goals_limit > 0),
 budgets_limit integer check (budgets_limit > 0),
 reports_access boolean not null default false
);
insert into public.plans values
 ('free','Free',0,null,50,8,1,5,false),
 ('plus','Plus',9900,30,null,null,null,null,true),
 ('pro','Pro',19900,30,null,null,null,null,true);
create table if not exists public.subscriptions (
 user_id uuid primary key references auth.users(id) on delete cascade,
 plan text not null default 'free' references public.plans(code),
 status text not null default 'active' check (status in ('active','cancelled','expired')),
 expires_at timestamptz,
 updated_at timestamptz not null default now(),
 constraint paid_subscription_expires check (plan='free' or expires_at is not null)
);
alter table public.plans enable row level security;
alter table public.subscriptions enable row level security;
revoke all on public.plans,public.subscriptions from public,anon,authenticated;
grant select on public.plans to anon,authenticated;
grant select on public.subscriptions to authenticated;
create policy public_plan_catalog on public.plans for select to anon,authenticated using (true);
create policy own_subscription_read on public.subscriptions for select to authenticated using (user_id=(select auth.uid()));
-- Existing users and future registrations start Free. No metadata is consulted.
insert into public.subscriptions(user_id) select id from auth.users on conflict do nothing;
create function public.initialize_free_subscription() returns trigger language plpgsql security definer set search_path='' as $$
begin
 insert into public.subscriptions(user_id) values(new.id) on conflict do nothing;
 return new;
end $$;
revoke all on function public.initialize_free_subscription() from public,anon,authenticated;
create trigger initialize_free_subscription after insert on auth.users for each row execute function public.initialize_free_subscription();

-- One source of truth. No user_id argument: callers can only ask about themselves.
-- Expiry is evaluated on every call, so no cron or mutation is required.
create function public.get_entitlement() returns jsonb language plpgsql stable security definer set search_path='' as $$
declare s public.subscriptions; p public.plans;
begin
 if auth.uid() is null then raise exception 'Login diperlukan.' using errcode='42501'; end if;
 select * into s from public.subscriptions where user_id=auth.uid();
 select * into p from public.plans where code=case when s.status='active' and s.plan<>'free' and s.expires_at>now() then s.plan else 'free' end;
 return jsonb_build_object('plan',p.code,'name',p.name,'status',case when p.code<>'free' then 'active' else 'free' end,
  'expires_at',case when p.code<>'free' then s.expires_at else null end,'reports_access',p.reports_access,
  'transactions_limit',p.transactions_limit,'categories_limit',p.categories_limit,'goals_limit',p.goals_limit,'budgets_limit',p.budgets_limit);
end $$;
revoke all on function public.get_entitlement() from public,anon;
grant execute on function public.get_entitlement() to authenticated;

-- Quotas serialize writes for one user, including simultaneous requests.
-- Existing rows above a limit remain readable/editable in the same quota bucket.
create function public.enforce_plan_limits() returns trigger language plpgsql set search_path='' as $$
declare e jsonb; lim integer; used integer; growing boolean:=true; bucket text; prior jsonb;
begin
 if auth.uid() is null or auth.uid()<>new.user_id then raise exception 'Akses ditolak.' using errcode='42501'; end if;
 if tg_op='UPDATE' and new.user_id<>old.user_id then raise exception 'Pemilik tidak dapat diubah.' using errcode='42501'; end if;
 perform pg_advisory_xact_lock(hashtextextended(new.user_id::text,0));
 e:=public.get_entitlement();
 -- PostgREST upsert executes BEFORE INSERT before resolving an existing ID.
 -- Recognize that row too, so legacy edits above the cap continue to work.
 if tg_op='UPDATE' and tg_table_name<>'categories' then prior:=old.data;
 elsif tg_op='INSERT' then
  if tg_table_name='transactions' then select data into prior from public.transactions where id=new.id and user_id=new.user_id;
  elsif tg_table_name='goals' then select data into prior from public.goals where id=new.id and user_id=new.user_id;
  elsif tg_table_name='budgets' then select data into prior from public.budgets where id=new.id and user_id=new.user_id;
  end if;
 end if;
 if tg_table_name='transactions' then
  lim:=(e->>'transactions_limit')::integer; bucket:=left(new.data->>'date',7);
  if prior is not null then growing:=left(prior->>'date',7) is distinct from bucket; end if;
  select count(*) into used from public.transactions where user_id=new.user_id and id<>new.id and left(data->>'date',7)=bucket;
 elsif tg_table_name='categories' then
  lim:=(e->>'categories_limit')::integer; growing:=tg_op='INSERT' and not exists(select 1 from public.categories where id=new.id and user_id=new.user_id);
  select count(*) into used from public.categories where user_id=new.user_id and id<>new.id;
 elsif tg_table_name='goals' then
  lim:=(e->>'goals_limit')::integer;
  growing:=(new.data->>'saved')::numeric<(new.data->>'target')::numeric;
  if prior is not null and (prior->>'saved')::numeric<(prior->>'target')::numeric then growing:=false; end if;
  select count(*) into used from public.goals where user_id=new.user_id and id<>new.id and (data->>'saved')::numeric<(data->>'target')::numeric;
 elsif tg_table_name='budgets' then
  lim:=(e->>'budgets_limit')::integer; bucket:=new.data->>'month';
  if prior is not null then growing:=(prior->>'month',prior->>'category') is distinct from (bucket,new.data->>'category'); end if;
  if exists(select 1 from public.budgets where user_id=new.user_id and id<>new.id and data->>'month'=bucket and data->>'category'=new.data->>'category') then growing:=false; end if;
  select count(distinct data->>'category') into used from public.budgets where user_id=new.user_id and id<>new.id and data->>'month'=bucket;
 end if;
 if growing and lim is not null and used>=lim then
  raise exception 'Batas Free tercapai (%: %). Upgrade ke Premium untuk menambah data. Data lama tetap tersimpan.',tg_table_name,lim using errcode='P0001',hint='PLAN_LIMIT';
 end if;
 return new;
end $$;
revoke all on function public.enforce_plan_limits() from public,anon,authenticated;
create trigger enforce_transactions_plan before insert or update on public.transactions for each row execute function public.enforce_plan_limits();
create trigger enforce_categories_plan before insert or update on public.categories for each row execute function public.enforce_plan_limits();
create trigger enforce_goals_plan before insert or update on public.goals for each row execute function public.enforce_plan_limits();
create trigger enforce_budgets_plan before insert or update on public.budgets for each row execute function public.enforce_plan_limits();

-- Premium report input is only obtainable through this gated RPC in the app.
-- SECURITY INVOKER retains Phase 1 RLS. There is no owner/user argument.
create function public.get_report_transactions(p_month text) returns table(id uuid,data jsonb)
language plpgsql security invoker set search_path='' as $$
declare start_date date;
begin
 if not (public.get_entitlement()->>'reports_access')::boolean then raise exception 'Laporan tersedia untuk Premium aktif. Upgrade ke Premium.' using errcode='42501'; end if;
 if p_month is null or p_month !~ '^\d{4}-(0[1-9]|1[0-2])$' then raise exception 'Bulan tidak valid.' using errcode='22023'; end if;
 start_date:=(p_month||'-01')::date;
 return query select t.id,t.data from public.transactions t where t.user_id=auth.uid()
  and (t.data->>'date')::date >= (start_date-interval '5 months')::date
  and (t.data->>'date')::date < (start_date+interval '1 month')::date order by t.data->>'date',t.id;
end $$;
revoke all on function public.get_report_transactions(text) from public,anon;
grant execute on function public.get_report_transactions(text) to authenticated;
notify pgrst,'reload schema';
commit;


-- ===== supabase/migrations/005_manual_checkout.sql =====
-- Session A: manual checkout. No payment provider, no automatic activation.
begin;
create table if not exists public.admin_users(user_id uuid primary key references auth.users(id) on delete cascade);
alter table public.admin_users enable row level security;
revoke all on public.admin_users from public,anon,authenticated;
create function public.is_admin() returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and exists(select 1 from public.admin_users where user_id=auth.uid());
$$;
revoke all on function public.is_admin() from public,anon;
grant execute on function public.is_admin() to authenticated;

create table if not exists public.products (
 id uuid primary key default gen_random_uuid(), code text unique not null check(code ~ '^[a-z0-9_-]{2,60}$'),
 name text not null check(length(name) between 1 and 120),
 type text not null check(type in ('subscription','early_access','digital_tool')),
 price_rupiah integer not null check(price_rupiah between 1 and 1000000000),
 duration_days integer check(duration_days between 1 and 3660), plan text references public.plans(code),
 active boolean not null default false, sort_order integer not null default 0,
 description text not null default '' check(length(description)<=1000),
 promo_starts_at timestamptz, promo_ends_at timestamptz,
 digital_file_path text,
 check(promo_ends_at is null or promo_starts_at is null or promo_ends_at>promo_starts_at),
 check((type='digital_tool' and plan is null) or (type<>'digital_tool' and plan in ('plus','pro') and duration_days is not null))
);
create table if not exists public.payment_settings (
 id uuid primary key default gen_random_uuid(), product_id uuid unique references public.products(id),
 merchant_name text not null check(length(merchant_name) between 1 and 120),
 qris_path text not null check(length(qris_path) between 1 and 250),
 instructions text not null default '' check(length(instructions)<=1000),
 enabled boolean not null default false, unique_amount_enabled boolean not null default false
);
create unique index if not exists one_global_payment_setting on public.payment_settings((true)) where product_id is null;
create table if not exists public.orders (
 id uuid primary key default gen_random_uuid(),
 order_number text unique not null,
 user_id uuid not null references auth.users(id), product_id uuid not null references public.products(id),
 request_id uuid not null,
 product_name text not null, product_type text not null, price_rupiah integer not null,
 unique_amount integer not null default 0 check(unique_amount between 0 and 999),
 total_rupiah integer not null check(total_rupiah>0), duration_days integer, plan text,
 merchant_name text not null, qris_path text not null, payment_instructions text not null,
 status text not null default 'pending' check(status in ('pending','submitted','paid','rejected','expired')),
 expires_at timestamptz not null, created_at timestamptz not null default now(), submitted_at timestamptz,
 reviewed_by uuid references auth.users(id), reviewed_at timestamptz, review_note text,
 unique(user_id,request_id), unique(id,user_id), check(total_rupiah=price_rupiah+unique_amount)
);
create index if not exists orders_owner_created on public.orders(user_id,created_at desc);
create table if not exists public.payment_confirmations (
 id uuid primary key default gen_random_uuid(), order_id uuid unique not null,
 user_id uuid not null references auth.users(id), reference text not null check(length(reference) between 3 and 120),
 note text not null default '' check(length(note)<=1000), proof_path text,
 submitted_at timestamptz not null default now(),
 foreign key(order_id,user_id) references public.orders(id,user_id),
 check(proof_path is null or proof_path like user_id::text||'/'||order_id::text||'/%')
);
create index if not exists confirmation_reference on public.payment_confirmations(lower(btrim(reference)));
create table if not exists public.entitlements (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id),
 plan text not null references public.plans(code) check(plan in ('plus','pro')),
 starts_at timestamptz not null, ends_at timestamptz not null check(ends_at>starts_at),
 source_order_id uuid unique not null,
 foreign key(source_order_id,user_id) references public.orders(id,user_id)
);
create index if not exists entitlement_active_owner on public.entitlements(user_id,ends_at);
alter table public.products enable row level security;
alter table public.payment_settings enable row level security;
alter table public.orders enable row level security;
alter table public.payment_confirmations enable row level security;
alter table public.entitlements enable row level security;
revoke all on public.products,public.payment_settings,public.orders,public.payment_confirmations,public.entitlements from public,anon,authenticated;
grant select on public.products,public.payment_settings to anon,authenticated;
grant select on public.orders,public.payment_confirmations,public.entitlements to authenticated;
create policy active_products on public.products for select to anon,authenticated using(active and (promo_starts_at is null or promo_starts_at<=now()) and (promo_ends_at is null or promo_ends_at>now()));
create policy enabled_payment_settings on public.payment_settings for select to anon,authenticated using(enabled);
create policy own_orders on public.orders for select to authenticated using(user_id=(select auth.uid()));
create policy own_confirmations on public.payment_confirmations for select to authenticated using(user_id=(select auth.uid()));
create policy own_entitlements on public.entitlements for select to authenticated using(user_id=(select auth.uid()));
-- Only the database owner can configure products/QRIS for now; admin UI is Session B.
insert into public.products(code,name,type,price_rupiah,duration_days,plan,active,sort_order,description) values
 ('plus-30','Plus 30 hari','subscription',9900,30,'plus',true,1,'Kuota tanpa batas, Laporan Premium dan ekspor CSV. Recurring belum tersedia.'),
 ('pro-30','Pro 30 hari','subscription',19900,30,'pro',true,2,'Semua fitur Plus yang tersedia. Analitik lanjutan, forecast dan health belum tersedia.'),
 ('early-access','Early Access Pro 12 bulan','early_access',25000,365,'pro',false,3,'Promo terbatas; harga dan periode promo harus ditetapkan admin. Bukan lifetime.');

-- One entitlement truth, compatible with protected legacy subscriptions.
create or replace function public.get_entitlement() returns jsonb language plpgsql stable security definer set search_path='' as $$
declare p public.plans; effective text; until_at timestamptz;
begin
 if auth.uid() is null then raise exception 'Login diperlukan.' using errcode='42501'; end if;
 select x.plan,max(x.ends_at) into effective,until_at from (
  select e.plan,e.ends_at from public.entitlements e where e.user_id=auth.uid() and e.starts_at<=now() and e.ends_at>now()
  union all select s.plan,s.expires_at from public.subscriptions s where s.user_id=auth.uid() and s.status='active' and s.plan<>'free' and s.expires_at>now()
 ) x group by x.plan order by case x.plan when 'pro' then 2 else 1 end desc limit 1;
 select * into p from public.plans where code=coalesce(effective,'free');
 return jsonb_build_object('plan',p.code,'name',p.name,'status',case when p.code<>'free' then 'active' else 'free' end,'expires_at',until_at,
 'reports_access',p.reports_access,'transactions_limit',p.transactions_limit,'categories_limit',p.categories_limit,'goals_limit',p.goals_limit,'budgets_limit',p.budgets_limit);
end $$;

-- No price argument. Browser amounts never reach order pricing.
create function public.create_order(p_product_code text,p_request_id uuid) returns public.orders language plpgsql security definer set search_path='' as $$
declare p public.products; cfg public.payment_settings; o public.orders; new_id uuid:=gen_random_uuid(); addition integer:=0;
begin
 if auth.uid() is null then raise exception 'Login diperlukan.' using errcode='42501'; end if;
 if p_request_id is null then raise exception 'ID permintaan diperlukan.' using errcode='22023'; end if;
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text,1));
 select * into o from public.orders where user_id=auth.uid() and request_id=p_request_id;
 if found then return o; end if;
 select * into p from public.products where code=p_product_code and active and (promo_starts_at is null or promo_starts_at<=now()) and (promo_ends_at is null or promo_ends_at>now());
 if not found then raise exception 'Produk belum tersedia.' using errcode='22023'; end if;
 select * into cfg from public.payment_settings where enabled and (product_id=p.id or product_id is null) order by product_id nulls last limit 1;
 if not found then raise exception 'Pembayaran belum tersedia. QRIS merchant resmi belum dikonfigurasi.' using errcode='22023'; end if;
 if not exists(select 1 from storage.objects where bucket_id='merchant-qris' and name=cfg.qris_path) then raise exception 'Pembayaran belum tersedia. Aset QRIS belum tersedia.' using errcode='22023'; end if;
 if p.type='digital_tool' then raise exception 'Pembelian tools belum tersedia pada sesi ini.' using errcode='22023'; end if;
 if cfg.unique_amount_enabled then
  perform pg_advisory_xact_lock(hashtextextended(cfg.merchant_name,2));
  select i into addition from generate_series(1,999) i where not exists(select 1 from public.orders x where x.merchant_name=cfg.merchant_name and x.total_rupiah=p.price_rupiah+i and (x.status='submitted' or (x.status='pending' and x.expires_at>now()))) order by i limit 1;
  if addition is null then raise exception 'Nominal pencocokan belum tersedia. Coba lagi nanti.' using errcode='22023'; end if;
 end if;
 insert into public.orders(id,order_number,user_id,product_id,request_id,product_name,product_type,price_rupiah,unique_amount,total_rupiah,duration_days,plan,merchant_name,qris_path,payment_instructions,expires_at)
 values(new_id,'MB-'||to_char(now() at time zone 'Asia/Jakarta','YYMMDD')||'-'||upper(left(replace(new_id::text,'-',''),10)),auth.uid(),p.id,p_request_id,p.name,p.type,p.price_rupiah,addition,p.price_rupiah+addition,p.duration_days,p.plan,cfg.merchant_name,cfg.qris_path,cfg.instructions,now()+interval '24 hours') returning * into o;
 return o;
end $$;
create function public.list_my_orders() returns setof public.orders language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null then raise exception 'Login diperlukan.' using errcode='42501'; end if;
 update public.orders set status='expired' where user_id=auth.uid() and status='pending' and expires_at<=now();
 return query select * from public.orders where user_id=auth.uid() order by created_at desc limit 100;
end $$;
create function public.submit_payment_confirmation(p_order_id uuid,p_reference text,p_note text default '',p_proof_path text default null)
returns public.orders language plpgsql security definer set search_path='' as $$
declare o public.orders;
begin
 if auth.uid() is null then raise exception 'Login diperlukan.' using errcode='42501'; end if;
 select * into o from public.orders where id=p_order_id and user_id=auth.uid() for update;
 if not found then raise exception 'Pesanan tidak ditemukan.' using errcode='42501'; end if;
 if o.status='submitted' then return o; end if;
 if o.status='pending' and o.expires_at<=now() then raise exception 'Batas waktu pesanan sudah lewat. Muat ulang pesanan.' using errcode='22023'; end if;
 if o.status<>'pending' then raise exception 'Pesanan ini tidak dapat dikonfirmasi.' using errcode='22023'; end if;
 if p_reference is null or length(btrim(p_reference)) not between 3 and 120 or p_note is null or length(p_note)>1000 then raise exception 'Periksa referensi (3–120 karakter) dan catatan (maksimal 1.000).' using errcode='22023'; end if;
 if p_proof_path is not null and (p_proof_path not like auth.uid()::text||'/'||o.id::text||'/%' or not exists(select 1 from storage.objects where bucket_id='payment-proofs' and name=p_proof_path and metadata->>'mimetype' in ('image/jpeg','image/png','image/webp') and (metadata->>'size')::bigint between 1 and 5242880)) then raise exception 'Bukti pembayaran tidak valid.' using errcode='42501'; end if;
 insert into public.payment_confirmations(order_id,user_id,reference,note,proof_path) values(o.id,auth.uid(),btrim(p_reference),p_note,p_proof_path);
 update public.orders set status='submitted',submitted_at=now() where id=o.id returning * into o;
 -- Never write subscriptions/entitlements here. Only admin review may grant access.
 return o;
end $$;
revoke all on function public.create_order(text,uuid),public.list_my_orders(),public.submit_payment_confirmation(uuid,text,text,text) from public,anon;
grant execute on function public.create_order(text,uuid),public.list_my_orders(),public.submit_payment_confirmation(uuid,text,text,text) to authenticated;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values
 ('payment-proofs','payment-proofs',false,5242880,array['image/jpeg','image/png','image/webp']),
 ('merchant-qris','merchant-qris',true,5242880,array['image/jpeg','image/png','image/webp']) on conflict(id) do update set public=excluded.public,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;
create policy own_payment_proof_upload on storage.objects for insert to authenticated with check(bucket_id='payment-proofs' and (storage.foldername(name))[1]=auth.uid()::text and exists(select 1 from public.orders o where o.id::text=(storage.foldername(name))[2] and o.user_id=auth.uid() and o.status='pending' and o.expires_at>now()));
create policy own_or_admin_proof_read on storage.objects for select to authenticated using(bucket_id='payment-proofs' and ((storage.foldername(name))[1]=auth.uid()::text or public.is_admin()));
-- No overwrite/delete of submitted evidence. No public proof read policy.
-- QRIS uploads are only for protected admins, configured manually until Session B.
create policy admin_qris_insert on storage.objects for insert to authenticated with check(bucket_id='merchant-qris' and public.is_admin());
notify pgrst,'reload schema';
commit;


-- ===== supabase/migrations/006_admin_purchases.sql =====
-- Protected purchase administration. No policies granting access to private finance.
begin;
create table if not exists public.audit_logs (
 id uuid primary key default gen_random_uuid(), admin_id uuid references auth.users(id),
 action text not null, object_id text not null, before_data jsonb, after_data jsonb,
 created_at timestamptz not null default now()
);
alter table public.audit_logs enable row level security;
revoke all on public.audit_logs from public,anon,authenticated;
grant select on public.audit_logs to authenticated;
create policy admin_audit_read on public.audit_logs for select to authenticated using(public.is_admin());
create policy admin_orders_read on public.orders for select to authenticated using(public.is_admin());
create policy admin_confirmations_read on public.payment_confirmations for select to authenticated using(public.is_admin());
create policy admin_entitlements_read on public.entitlements for select to authenticated using(public.is_admin());

create function public.admin_review_order(p_order_id uuid,p_decision text,p_note text default '') returns jsonb
language plpgsql security definer set search_path='' as $$
declare o public.orders; original_status text; begins timestamptz; ends timestamptz; entitlement_id uuid;
begin
 if not public.is_admin() then raise exception 'Akses admin diperlukan.' using errcode='42501'; end if;
 if p_decision is null or p_decision not in ('paid','rejected') or p_note is null or length(p_note)>1000 or (p_decision='rejected' and length(btrim(p_note))=0) then
  raise exception 'Pilih keputusan dan isi catatan penolakan (maksimal 1.000 karakter).' using errcode='22023'; end if;
 select * into o from public.orders where id=p_order_id for update;
 if not found then raise exception 'Pesanan tidak ditemukan.' using errcode='22023'; end if;
 if o.status='paid' and p_decision='paid' then return jsonb_build_object('result','already_paid','order',to_jsonb(o)); end if;
 if o.status<>'submitted' then raise exception 'Hanya pesanan menunggu verifikasi yang dapat diperiksa.' using errcode='22023'; end if;
 original_status:=o.status;
 -- Serialize different orders for the same user too, so renewal durations never overlap.
 perform pg_advisory_xact_lock(hashtextextended(o.user_id::text,1));
 if p_decision='paid' and o.product_type<>'digital_tool' then
  if o.plan not in ('plus','pro') or o.duration_days is null or o.duration_days<1 then raise exception 'Snapshot paket tidak valid.' using errcode='22023'; end if;
  select greatest(now(),coalesce(max(x.until_at),now())) into begins from (
   select e.ends_at as until_at from public.entitlements e where e.user_id=o.user_id and e.plan=o.plan and e.ends_at>now()
   union all select s.expires_at from public.subscriptions s where s.user_id=o.user_id and s.plan=o.plan and s.status='active' and s.expires_at>now()
  ) x;
  ends:=begins+make_interval(days=>o.duration_days);
  insert into public.entitlements(user_id,plan,starts_at,ends_at,source_order_id) values(o.user_id,o.plan,begins,ends,o.id) returning id into entitlement_id;
 end if;
 update public.orders set status=p_decision,reviewed_by=auth.uid(),reviewed_at=now(),review_note=btrim(p_note) where id=o.id returning * into o;
 insert into public.audit_logs(admin_id,action,object_id,before_data,after_data)
 values(auth.uid(),'order.'||p_decision,o.id::text,jsonb_build_object('status',original_status),jsonb_build_object('status',p_decision,'note',btrim(p_note),'entitlement_id',entitlement_id,'starts_at',begins,'ends_at',ends));
 return jsonb_build_object('result','reviewed','order',to_jsonb(o));
end $$;

create function public.admin_purchase_summary() returns jsonb language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
 if not public.is_admin() then raise exception 'Akses admin diperlukan.' using errcode='42501'; end if;
 select jsonb_build_object('users',(select count(*) from auth.users),'statuses',(select coalesce(jsonb_object_agg(status,n),'{}') from (select status,count(*) n from public.orders group by status) s),
 'verified_count',(select count(*) from public.orders where status='paid'),
 'subscription_revenue',(select coalesce(sum(total_rupiah),0) from public.orders where status='paid' and product_type<>'digital_tool'),
 'tools_revenue',(select coalesce(sum(total_rupiah),0) from public.orders where status='paid' and product_type='digital_tool'),
 'active_plans',(select count(distinct user_id) from (
  select user_id from public.entitlements where starts_at<=now() and ends_at>now()
  union select user_id from public.subscriptions where plan<>'free' and status='active' and expires_at>now()
 ) active_users)) into result;
 return result;
end $$;

create function public.admin_list_orders(p_search text default '',p_status text default '',p_product uuid default null,p_from date default null,p_to date default null,p_offset integer default 0)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
 if not public.is_admin() then raise exception 'Akses admin diperlukan.' using errcode='42501'; end if;
 if p_search is null or length(p_search)>120 or p_offset is null or p_offset<0 or p_status not in ('','pending','submitted','paid','rejected','expired') or (p_from is not null and p_to is not null and p_from>p_to) then raise exception 'Filter tidak valid.' using errcode='22023'; end if;
 select coalesce(jsonb_agg(row_data),'[]') into result from (
  select to_jsonb(o)||jsonb_build_object('buyer_name',coalesce(u.raw_user_meta_data->>'name',''),'buyer_email',u.email,
  'reference',c.reference,'confirmation_note',c.note,'proof_path',c.proof_path,
  'duplicate_reference',case when c.reference is null then false else exists(select 1 from public.payment_confirmations other where other.order_id<>o.id and lower(btrim(other.reference))=lower(btrim(c.reference))) end,
  'access_starts_at',e.starts_at,'access_ends_at',e.ends_at) as row_data
  from public.orders o join auth.users u on u.id=o.user_id
  left join public.payment_confirmations c on c.order_id=o.id left join public.entitlements e on e.source_order_id=o.id
  where (p_status='' or o.status=p_status) and (p_product is null or o.product_id=p_product)
   and (p_from is null or o.created_at >= (p_from::timestamp at time zone 'Asia/Jakarta'))
   and (p_to is null or o.created_at < ((p_to+1)::timestamp at time zone 'Asia/Jakarta'))
   and (p_search='' or position(lower(p_search) in lower(o.order_number||' '||o.product_name||' '||coalesce(u.email,'')||' '||coalesce(u.raw_user_meta_data->>'name','')))>0)
  order by o.created_at desc,o.id limit 50 offset p_offset
 ) rows;
 return result;
end $$;
-- Only display names from Auth are included. No reads of profiles/transactions/budgets/goals.
revoke all on function public.admin_review_order(uuid,text,text),public.admin_purchase_summary(),public.admin_list_orders(text,text,uuid,date,date,integer) from public,anon;
grant execute on function public.admin_review_order(uuid,text,text),public.admin_purchase_summary(),public.admin_list_orders(text,text,uuid,date,date,integer) to authenticated;
notify pgrst,'reload schema';
commit;


-- ===== supabase/migrations/007_product_settings.sql =====
begin;
create policy admin_products_read on public.products for select to authenticated using(public.is_admin());
create policy admin_payment_settings_read on public.payment_settings for select to authenticated using(public.is_admin());
create table if not exists public.download_logs(id uuid primary key default gen_random_uuid(),user_id uuid not null references auth.users(id),product_id uuid not null references public.products(id),created_at timestamptz not null default now());
alter table public.download_logs enable row level security;
revoke all on public.download_logs from public,anon,authenticated;
grant select on public.download_logs to authenticated;
create policy own_download_logs on public.download_logs for select to authenticated using(user_id=auth.uid());
create function public.admin_save_product(p_data jsonb) returns public.products language plpgsql security definer set search_path='' as $$
declare before_row public.products; after_row public.products; product_id uuid;
begin
 if not public.is_admin() then raise exception 'Akses admin diperlukan.' using errcode='42501'; end if;
 if p_data is null or jsonb_typeof(p_data)<>'object' then raise exception 'Produk tidak valid.' using errcode='22023'; end if;
 product_id:=coalesce((p_data->>'id')::uuid,gen_random_uuid());
 select * into before_row from public.products where id=product_id for update;
 if p_data->>'type'='early_access' and (p_data->>'active')::boolean and (nullif(p_data->>'promo_starts_at','') is null or nullif(p_data->>'promo_ends_at','') is null) then raise exception 'Early Access aktif memerlukan periode promo.' using errcode='22023'; end if;
 if nullif(p_data->>'digital_file_path','') is not null and not exists(select 1 from storage.objects where bucket_id='digital-files' and name=p_data->>'digital_file_path') then raise exception 'File privat tidak ditemukan.' using errcode='22023'; end if;
 if p_data->>'type'='digital_tool' and (p_data->>'active')::boolean and nullif(p_data->>'digital_file_path','') is null then raise exception 'Unggah file pendukung sebelum mengaktifkan produk digital.' using errcode='22023'; end if;
 insert into public.products(id,code,name,type,price_rupiah,duration_days,plan,active,sort_order,description,promo_starts_at,promo_ends_at,digital_file_path)
 values(product_id,p_data->>'code',btrim(p_data->>'name'),p_data->>'type',(p_data->>'price_rupiah')::integer,(p_data->>'duration_days')::integer,p_data->>'plan',(p_data->>'active')::boolean,(p_data->>'sort_order')::integer,p_data->>'description',nullif(p_data->>'promo_starts_at','')::timestamptz,nullif(p_data->>'promo_ends_at','')::timestamptz,nullif(p_data->>'digital_file_path',''))
 on conflict(id) do update set code=excluded.code,name=excluded.name,type=excluded.type,price_rupiah=excluded.price_rupiah,duration_days=excluded.duration_days,plan=excluded.plan,active=excluded.active,sort_order=excluded.sort_order,description=excluded.description,promo_starts_at=excluded.promo_starts_at,promo_ends_at=excluded.promo_ends_at,digital_file_path=excluded.digital_file_path returning * into after_row;
 insert into public.audit_logs(admin_id,action,object_id,before_data,after_data) values(auth.uid(),'product.save',product_id::text,to_jsonb(before_row),to_jsonb(after_row));
 return after_row;
end $$;
create function public.admin_save_payment_settings(p_data jsonb) returns public.payment_settings language plpgsql security definer set search_path='' as $$
declare before_row public.payment_settings; after_row public.payment_settings; setting_id uuid;
begin
 if not public.is_admin() then raise exception 'Akses admin diperlukan.' using errcode='42501'; end if;
 if p_data is null or jsonb_typeof(p_data)<>'object' then raise exception 'Pengaturan tidak valid.' using errcode='22023'; end if;
 setting_id:=coalesce((p_data->>'id')::uuid,gen_random_uuid());
 select * into before_row from public.payment_settings where id=setting_id for update;
 if not exists(select 1 from storage.objects where bucket_id='merchant-qris' and name=p_data->>'qris_path' and metadata->>'mimetype' in('image/jpeg','image/png','image/webp') and (metadata->>'size')::bigint between 1 and 5242880) then raise exception 'Unggah gambar QRIS resmi lebih dahulu.' using errcode='22023'; end if;
 insert into public.payment_settings(id,product_id,merchant_name,qris_path,instructions,enabled,unique_amount_enabled)
 values(setting_id,(p_data->>'product_id')::uuid,btrim(p_data->>'merchant_name'),p_data->>'qris_path',p_data->>'instructions',(p_data->>'enabled')::boolean,(p_data->>'unique_amount_enabled')::boolean)
 on conflict(id) do update set product_id=excluded.product_id,merchant_name=excluded.merchant_name,qris_path=excluded.qris_path,instructions=excluded.instructions,enabled=excluded.enabled,unique_amount_enabled=excluded.unique_amount_enabled returning * into after_row;
 insert into public.audit_logs(admin_id,action,object_id,before_data,after_data) values(auth.uid(),'payment_settings.save',setting_id::text,to_jsonb(before_row),to_jsonb(after_row));return after_row;
end $$;
create function public.admin_record_asset(p_bucket text,p_path text) returns void language plpgsql security definer set search_path='' as $$
begin
 if not public.is_admin() then raise exception 'Akses admin diperlukan.' using errcode='42501'; end if;
 if p_bucket not in ('merchant-qris','digital-files','site-assets') or p_path not like auth.uid()::text||'/%' or not exists(select 1 from storage.objects where bucket_id=p_bucket and name=p_path) then raise exception 'Aset tidak valid.' using errcode='22023'; end if;
 insert into public.audit_logs(admin_id,action,object_id,after_data) values(auth.uid(),'asset.upload',p_path,jsonb_build_object('bucket',p_bucket));
end $$;
create function public.get_paid_download(p_product_id uuid) returns text language plpgsql security definer set search_path='' as $$
declare file_path text;
begin
 if auth.uid() is null or not exists(select 1 from public.orders where user_id=auth.uid() and product_id=p_product_id and status='paid' and product_type='digital_tool') then raise exception 'Pembelian terverifikasi diperlukan.' using errcode='42501'; end if;
 select digital_file_path into file_path from public.products where id=p_product_id and type='digital_tool';
 if file_path is null or not exists(select 1 from storage.objects where bucket_id='digital-files' and name=file_path) then raise exception 'File belum tersedia.' using errcode='22023'; end if;
 insert into public.download_logs(user_id,product_id) values(auth.uid(),p_product_id);return file_path;
end $$;
revoke all on function public.admin_save_product(jsonb),public.admin_save_payment_settings(jsonb),public.admin_record_asset(text,text),public.get_paid_download(uuid) from public,anon;
grant execute on function public.admin_save_product(jsonb),public.admin_save_payment_settings(jsonb),public.admin_record_asset(text,text),public.get_paid_download(uuid) to authenticated;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('digital-files','digital-files',false,20971520,array['application/pdf','text/csv','application/vnd.openxmlformats-officedocument.spreadsheetml.sheet']),('site-assets','site-assets',true,2097152,array['image/jpeg','image/png','image/webp']) on conflict(id) do update set public=excluded.public,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;
create policy admin_digital_insert on storage.objects for insert to authenticated with check(bucket_id='digital-files' and public.is_admin() and (storage.foldername(name))[1]=auth.uid()::text);
create function public.can_read_paid_file(p_path text) returns boolean language sql stable security definer set search_path='' as $$ select auth.uid() is not null and exists(select 1 from public.products p join public.orders o on o.product_id=p.id where p.digital_file_path=p_path and o.user_id=auth.uid() and o.status='paid' and o.product_type='digital_tool'); $$;
revoke all on function public.can_read_paid_file(text) from public,anon;
grant execute on function public.can_read_paid_file(text) to authenticated;
create policy paid_digital_read on storage.objects for select to authenticated using(bucket_id='digital-files' and (public.is_admin() or public.can_read_paid_file(name)));
create policy admin_site_asset_insert on storage.objects for insert to authenticated with check(bucket_id='site-assets' and public.is_admin() and (storage.foldername(name))[1]=auth.uid()::text);
-- Historical orders are never edited by catalogue/configuration RPCs.
create or replace function public.create_order(p_product_code text,p_request_id uuid) returns public.orders language plpgsql security definer set search_path='' as $$
declare p public.products; cfg public.payment_settings; o public.orders; new_id uuid:=gen_random_uuid(); addition integer:=0;
begin
 if auth.uid() is null then raise exception 'Login diperlukan.' using errcode='42501'; end if;
 if p_request_id is null then raise exception 'ID permintaan diperlukan.' using errcode='22023'; end if;
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text,1));
 select * into o from public.orders where user_id=auth.uid() and request_id=p_request_id;if found then return o; end if;
 select * into p from public.products where code=p_product_code and active and (promo_starts_at is null or promo_starts_at<=now()) and (promo_ends_at is null or promo_ends_at>now());
 if not found then raise exception 'Produk belum tersedia.' using errcode='22023'; end if;
 if p.type='digital_tool' and (p.digital_file_path is null or not exists(select 1 from storage.objects where bucket_id='digital-files' and name=p.digital_file_path)) then raise exception 'File produk belum tersedia.' using errcode='22023'; end if;
 select * into cfg from public.payment_settings where enabled and (product_id=p.id or product_id is null) order by product_id nulls last limit 1;
 if not found then raise exception 'Pembayaran belum tersedia. QRIS merchant resmi belum dikonfigurasi.' using errcode='22023'; end if;
 if not exists(select 1 from storage.objects where bucket_id='merchant-qris' and name=cfg.qris_path) then raise exception 'Pembayaran belum tersedia. Aset QRIS belum tersedia.' using errcode='22023'; end if;
 if cfg.unique_amount_enabled then
  perform pg_advisory_xact_lock(hashtextextended(cfg.merchant_name,2));
  select i into addition from generate_series(1,999) i where not exists(select 1 from public.orders x where x.merchant_name=cfg.merchant_name and x.total_rupiah=p.price_rupiah+i and (x.status='submitted' or (x.status='pending' and x.expires_at>now()))) order by i limit 1;
  if addition is null then raise exception 'Nominal pencocokan belum tersedia. Coba lagi nanti.' using errcode='22023'; end if;
 end if;
 insert into public.orders(id,order_number,user_id,product_id,request_id,product_name,product_type,price_rupiah,unique_amount,total_rupiah,duration_days,plan,merchant_name,qris_path,payment_instructions,expires_at)
 values(new_id,'MB-'||to_char(now() at time zone 'Asia/Jakarta','YYMMDD')||'-'||upper(left(replace(new_id::text,'-',''),10)),auth.uid(),p.id,p_request_id,p.name,p.type,p.price_rupiah,addition,p.price_rupiah+addition,p.duration_days,p.plan,cfg.merchant_name,cfg.qris_path,cfg.instructions,now()+interval '24 hours') returning * into o;return o;
end $$;
notify pgrst,'reload schema';
commit;


-- ===== supabase/migrations/008_site_content.sql =====
begin;
create function public.valid_site_destination(v text) returns boolean language sql immutable set search_path='' as $$
 select coalesce(length(v) between 1 and 500 and v !~ '[[:space:]<>]' and position(chr(92) in v)=0 and ((left(v,1)='/' and left(v,2)<>'//') or v ~ '^https?://[^/@[:space:]]+([/?#][^[:space:]]*)?$'),false);
$$;
create function public.valid_site_content(c jsonb) returns boolean language plpgsql immutable set search_path='' as $$
declare item jsonb; field text;
begin
 if c is null or jsonb_typeof(c)<>'object' then return false; end if;
 foreach field in array array['headline','description','cta_label','cta_url','feature_heading','footer'] loop
  if jsonb_typeof(c->field) is distinct from 'string' or length(btrim(c->>field))=0 then return false;end if;
 end loop;
 if length(c->>'headline')>120 or length(c->>'description')>500 or length(c->>'cta_label')>40 or length(c->>'feature_heading')>120 or length(c->>'footer')>240 or not public.valid_site_destination(c->>'cta_url') then return false;end if;
 if not c ? 'logo_path' or (c->'logo_path'<>'null'::jsonb and (jsonb_typeof(c->'logo_path')<>'string' or (c->>'logo_path'<>'/brand/mybudget-logo.png' and c->>'logo_path' !~ '^[0-9a-f-]{36}/[0-9a-f-]{36}\.(png|jpg|webp)$'))) then return false;end if;
 if jsonb_typeof(c->'features') is distinct from 'array' or jsonb_typeof(c->'steps') is distinct from 'array' then return false;end if;
 if jsonb_array_length(c->'features') not between 1 and 6 or jsonb_array_length(c->'steps') not between 1 and 4 then return false;end if;
 for item in select value from jsonb_array_elements(c->'features') loop
  if jsonb_typeof(item->'title') is distinct from 'string' or jsonb_typeof(item->'description') is distinct from 'string' or length(btrim(item->>'title')) not between 1 and 80 or length(btrim(item->>'description')) not between 1 and 240 then return false;end if;
 end loop;
 for item in select value from jsonb_array_elements(c->'steps') loop
  if jsonb_typeof(item->'title') is distinct from 'string' or jsonb_typeof(item->'description') is distinct from 'string' or length(btrim(item->>'title')) not between 1 and 40 or length(btrim(item->>'description')) not between 1 and 180 then return false;end if;
 end loop;
 return true;
end $$;
create table if not exists public.site_content_draft(id integer primary key default 1 check(id=1),content jsonb not null check(public.valid_site_content(content)),revision integer not null default 1,updated_by uuid not null references auth.users(id),updated_at timestamptz not null default now());
create table if not exists public.site_content_published(id integer primary key default 1 check(id=1),content jsonb not null check(public.valid_site_content(content)),revision integer not null,published_by uuid not null references auth.users(id),published_at timestamptz not null default now());
alter table public.site_content_draft enable row level security;
alter table public.site_content_published enable row level security;
revoke all on public.site_content_draft,public.site_content_published from public,anon,authenticated;
grant select on public.site_content_draft to authenticated;
grant select on public.site_content_published to anon,authenticated;
create policy admin_draft_read on public.site_content_draft for select to authenticated using(public.is_admin());
create policy published_read on public.site_content_published for select to anon,authenticated using(true);
create function public.admin_save_site_draft(p_content jsonb,p_revision integer) returns public.site_content_draft language plpgsql security definer set search_path='' as $$
declare d public.site_content_draft; old_revision integer;
begin
 if not public.is_admin() then raise exception 'Akses admin diperlukan.' using errcode='42501';end if;
 if p_revision is null or not public.valid_site_content(p_content) then raise exception 'Konten/URL tidak valid.' using errcode='22023';end if;
 if p_content->>'logo_path' is not null and p_content->>'logo_path'<>'/brand/mybudget-logo.png' and not exists(select 1 from storage.objects where bucket_id='site-assets' and name=p_content->>'logo_path') then raise exception 'Aset logo tidak ditemukan.' using errcode='22023';end if;
 perform pg_advisory_xact_lock(81234567);
 select * into d from public.site_content_draft where id=1 for update;old_revision:=coalesce(d.revision,0);
 if p_revision<>old_revision then raise exception 'Draft berubah. Muat ulang sebelum menyimpan.' using errcode='22023';end if;
 insert into public.site_content_draft(id,content,revision,updated_by) values(1,p_content,old_revision+1,auth.uid()) on conflict(id) do update set content=excluded.content,revision=excluded.revision,updated_by=excluded.updated_by,updated_at=now() returning * into d;
 insert into public.audit_logs(admin_id,action,object_id,before_data,after_data) values(auth.uid(),'content.draft','1',jsonb_build_object('revision',old_revision),jsonb_build_object('revision',d.revision));return d;
end $$;
create function public.admin_publish_site(p_revision integer) returns public.site_content_published language plpgsql security definer set search_path='' as $$
declare d public.site_content_draft; p public.site_content_published; old_revision integer;
begin
 if not public.is_admin() then raise exception 'Akses admin diperlukan.' using errcode='42501';end if;
 perform pg_advisory_xact_lock(81234567);
 select * into d from public.site_content_draft where id=1 for update;
 if not found or p_revision is null or d.revision<>p_revision then raise exception 'Simpan dan preview draft terbaru sebelum publish.' using errcode='22023';end if;
 select revision into old_revision from public.site_content_published where id=1;
 if old_revision=p_revision then select * into p from public.site_content_published where id=1;return p;end if;
 insert into public.site_content_published(id,content,revision,published_by) values(1,d.content,d.revision,auth.uid()) on conflict(id) do update set content=excluded.content,revision=excluded.revision,published_by=excluded.published_by,published_at=now() returning * into p;
 insert into public.audit_logs(admin_id,action,object_id,before_data,after_data) values(auth.uid(),'content.publish','1',jsonb_build_object('revision',old_revision),jsonb_build_object('revision',p.revision,'published_at',p.published_at));return p;
end $$;
revoke all on function public.admin_save_site_draft(jsonb,integer),public.admin_publish_site(integer) from public,anon;
grant execute on function public.admin_save_site_draft(jsonb,integer),public.admin_publish_site(integer) to authenticated;
notify pgrst,'reload schema';
commit;


-- ===== supabase/migrations/009_pro_analytics.sql =====
-- Owner-only analytics; reuses the tested entitlement resolver, including expiry.
begin;
create function public.get_effective_plan() returns text language sql stable security invoker set search_path='' as $$
 select coalesce(public.get_entitlement()->>'plan','free')
$$;
create function public.get_pro_analytics() returns jsonb language plpgsql stable security invoker set search_path='' as $$
begin
 if auth.uid() is null or public.get_effective_plan() is distinct from 'pro' then
  raise exception 'Pro aktif diperlukan' using errcode='42501';
 end if;
 return jsonb_build_object(
  'profile',(select data from public.profiles where user_id=auth.uid()),
  'transactions',coalesce((select jsonb_agg(data||jsonb_build_object('id',id)) from public.transactions where user_id=auth.uid()),'[]'::jsonb),
  'budgets',coalesce((select jsonb_agg(data||jsonb_build_object('id',id)) from public.budgets where user_id=auth.uid()),'[]'::jsonb),
  'goals',coalesce((select jsonb_agg(data||jsonb_build_object('id',id)) from public.goals where user_id=auth.uid()),'[]'::jsonb));
end $$;
create function public.set_projected_allocation(goal_id uuid, allocation bigint) returns void language plpgsql security invoker set search_path='' as $$
begin
 if auth.uid() is null or public.get_effective_plan() is distinct from 'pro' then raise exception 'Pro aktif diperlukan' using errcode='42501'; end if;
 if allocation is null or allocation<0 or allocation>1000000000000 then raise exception 'Alokasi tidak valid'; end if;
 update public.goals set data=jsonb_set(data,'{monthly}',to_jsonb(allocation)) where id=goal_id and user_id=auth.uid();
 if not found then raise exception 'Target tidak ditemukan' using errcode='42501'; end if;
end $$;
revoke all on function public.get_effective_plan(), public.get_pro_analytics(), public.set_projected_allocation(uuid,bigint) from public, anon;
grant execute on function public.get_effective_plan(), public.get_pro_analytics(), public.set_projected_allocation(uuid,bigint) to authenticated;
commit;


-- ===== supabase/migrations/010_recurring.sql =====
begin;
create table if not exists public.recurring_rules (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade,
 amount bigint not null check(amount between 1 and 1000000000000), type text not null check(type in ('income','expense')),
 category text not null check(category in ('Makan & minum','Transportasi','Belanja','Tagihan','Kesehatan','Hiburan','Lainnya','Project','Gaji')),
 description text not null default '' check(length(description)<=160), frequency text not null check(frequency in ('weekly','monthly')),
 starts_on date not null check(starts_on between date '2000-01-01' and date '2100-12-31'), ends_on date,
 active boolean not null default true, next_on date not null, check(ends_on is null or ends_on>=starts_on)
);
-- Ledger survives rule/transaction deletion, so a due date cannot be generated twice.
create table if not exists public.recurring_occurrences (
 rule_id uuid not null, due_on date not null, user_id uuid not null references auth.users(id) on delete cascade,
 transaction_id uuid not null, primary key(rule_id,due_on), unique(transaction_id)
);
alter table public.recurring_rules enable row level security;
alter table public.recurring_occurrences enable row level security;
revoke all on public.recurring_rules,public.recurring_occurrences from public,anon,authenticated;
grant select on public.recurring_rules,public.recurring_occurrences to authenticated;
create policy own_recurring on public.recurring_rules for select to authenticated using(user_id=auth.uid() and public.get_effective_plan() in ('plus','pro'));
create policy own_occurrences on public.recurring_occurrences for select to authenticated using(user_id=auth.uid());
-- Scheduling anchors monthly dates to starts_on, never the clamped February date.
create function public.recurring_next(anchor date,frequency text,after_on date) returns date language sql immutable set search_path='' as $$
 select case when frequency='weekly' then after_on+7 else
 (date_trunc('month',after_on::timestamp)+interval '1 month')::date +
 (least(extract(day from anchor)::int,extract(day from date_trunc('month',after_on::timestamp)+interval '2 months - 1 day')::int)-1) end
$$;
create function public.save_recurring(p_id uuid,p_amount bigint,p_type text,p_category text,p_description text,p_frequency text,p_start date,p_end date,p_active boolean) returns uuid language plpgsql security definer set search_path='' as $$
declare r public.recurring_rules; today date:=(now() at time zone 'Asia/Jakarta')::date; target uuid;
begin
 if auth.uid() is null or public.get_effective_plan() not in ('plus','pro') then raise exception 'Plus aktif diperlukan' using errcode='42501'; end if;
 if p_start is null or p_start<date '2000-01-01' or p_start>date '2100-12-31' or p_frequency is null or p_frequency not in ('weekly','monthly') then raise exception 'Jadwal tidak valid' using errcode='22023'; end if;
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text,0));
 if p_id is null then
  insert into public.recurring_rules(user_id,amount,type,category,description,frequency,starts_on,ends_on,active,next_on)
  values(auth.uid(),p_amount,p_type,p_category,p_description,p_frequency,p_start,p_end,p_active,p_start) returning id into target;
 else
  select * into r from public.recurring_rules where id=p_id and user_id=auth.uid() for update;
  if not found then raise exception 'Aturan tidak ditemukan' using errcode='42501'; end if;
  -- Schedule edits begin in the future; old occurrences are never changed/replayed.
  if r.starts_on<>p_start or r.frequency<>p_frequency or (not r.active and p_active) then
   r.next_on:=p_start;
   while r.next_on<=today loop r.next_on:=public.recurring_next(p_start,p_frequency,r.next_on); end loop;
  end if;
  update public.recurring_rules set amount=p_amount,type=p_type,category=p_category,description=p_description,
   frequency=p_frequency,starts_on=p_start,ends_on=p_end,active=p_active,next_on=r.next_on where id=p_id returning id into target;
 end if;
 return target;
end $$;
create function public.delete_recurring(p_id uuid) returns void language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or public.get_effective_plan() not in ('plus','pro') then raise exception 'Plus aktif diperlukan' using errcode='42501'; end if;
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text,0));
 delete from public.recurring_rules where id=p_id and user_id=auth.uid();
 if not found then raise exception 'Aturan tidak ditemukan' using errcode='42501'; end if;
end $$;
create function public.apply_recurring() returns jsonb language plpgsql security definer set search_path='' as $$
declare r public.recurring_rules; due date; tx uuid; made integer:=0; today date:=(now() at time zone 'Asia/Jakarta')::date;
begin
 if auth.uid() is null or public.get_effective_plan() not in ('plus','pro') then raise exception 'Plus aktif diperlukan' using errcode='42501'; end if;
 -- Same lock order as quota triggers. Parallel requests serialize per owner.
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text,0));
 for r in select * from public.recurring_rules where user_id=auth.uid() and active and next_on<=today order by next_on,id for update loop
  due:=r.next_on;
  while due<=today and (r.ends_on is null or due<=r.ends_on) and made<500 loop
   tx:=gen_random_uuid();
   insert into public.recurring_occurrences(rule_id,due_on,user_id,transaction_id) values(r.id,due,auth.uid(),tx) on conflict do nothing;
   if found then
    insert into public.transactions(id,user_id,data) values(tx,auth.uid(),jsonb_build_object('amount',r.amount,'type',r.type,'category',r.category,'description',r.description,'date',due::text));
    made:=made+1;
   end if;
   due:=public.recurring_next(r.starts_on,r.frequency,due);
  end loop;
  update public.recurring_rules set next_on=due where id=r.id;
  exit when made>=500;
 end loop;
 return jsonb_build_object('created',made,'more',exists(select 1 from public.recurring_rules where user_id=auth.uid() and active and next_on<=today and (ends_on is null or next_on<=ends_on)));
end $$;
revoke all on function public.recurring_next(date,text,date),public.save_recurring(uuid,bigint,text,text,text,text,date,date,boolean),public.delete_recurring(uuid),public.apply_recurring() from public,anon;
grant execute on function public.recurring_next(date,text,date),public.save_recurring(uuid,bigint,text,text,text,text,date,date,boolean),public.delete_recurring(uuid),public.apply_recurring() to authenticated;
commit;


-- ===== supabase/migrations/011_advanced_analysis.sql =====
begin;
create table if not exists public.insight_dismissals (
 user_id uuid not null references auth.users(id) on delete cascade,
 insight_key text not null check(length(insight_key) between 10 and 180 and insight_key like 'v1:%'),
 dismissed_at timestamptz not null default now(),primary key(user_id,insight_key)
);
alter table public.insight_dismissals enable row level security;
revoke all on public.insight_dismissals from public,anon,authenticated;
grant select,insert,delete on public.insight_dismissals to authenticated;
create policy own_pro_dismissals on public.insight_dismissals for all to authenticated
 using(user_id=auth.uid() and public.get_effective_plan()='pro')
 with check(user_id=auth.uid() and public.get_effective_plan()='pro');
create function public.get_advanced_insight_data() returns jsonb language plpgsql stable security invoker set search_path='' as $$
declare source jsonb;
begin
 source:=public.get_pro_analytics();
 return jsonb_build_object('transactions',source->'transactions','dismissed',coalesce((select jsonb_agg(insight_key) from public.insight_dismissals where user_id=auth.uid()),'[]'::jsonb));
end $$;
create function public.dismiss_insight(p_key text) returns void language plpgsql security invoker set search_path='' as $$
begin
 if auth.uid() is null or public.get_effective_plan() is distinct from 'pro' then raise exception 'Pro aktif diperlukan' using errcode='42501';end if;
 insert into public.insight_dismissals(user_id,insight_key) values(auth.uid(),p_key) on conflict do nothing;
end $$;
revoke all on function public.get_advanced_insight_data(),public.dismiss_insight(text) from public,anon;
grant execute on function public.get_advanced_insight_data(),public.dismiss_insight(text) to authenticated;
create function public.get_advanced_report_data(p_from date,p_to date,p_compare_from date,p_compare_to date) returns jsonb language plpgsql stable security invoker set search_path='' as $$
declare result jsonb;
begin
 if auth.uid() is null or public.get_effective_plan() is distinct from 'pro' then raise exception 'Pro aktif diperlukan' using errcode='42501';end if;
 if p_from is null or p_to is null or p_compare_from is null or p_compare_to is null
 or p_from>p_to or p_compare_from>p_compare_to or p_to-p_from>730 or p_compare_to-p_compare_from>730
 or p_from<date '2000-01-01' or p_compare_from<date '2000-01-01'
 or greatest(p_to,p_compare_to)>(now() at time zone 'Asia/Jakarta')::date then raise exception 'Periode tidak valid (maksimum 731 hari)' using errcode='22023';end if;
 if (select count(*) from public.transactions where user_id=auth.uid() and ((data->>'date')::date between p_from and p_to or (data->>'date')::date between p_compare_from and p_compare_to))>50000 then raise exception 'Perpendek periode: maksimum 50000 transaksi per laporan' using errcode='22023';end if;
 select coalesce(jsonb_agg(data||jsonb_build_object('id',id)),'[]'::jsonb) into result from public.transactions
 where user_id=auth.uid() and ((data->>'date')::date between p_from and p_to or (data->>'date')::date between p_compare_from and p_compare_to);
 return result;
end $$;
revoke all on function public.get_advanced_report_data(date,date,date,date) from public,anon;
grant execute on function public.get_advanced_report_data(date,date,date,date) to authenticated;
commit;


-- ===== supabase/migrations/012_digital_planners.sql =====
begin;
insert into public.products(code,name,type,price_rupiah,active,description) values
 ('budget-planner','Budget planner','digital_tool',9900,false,'Planner budget interaktif. Produk belum diaktifkan sebelum verifikasi.'),
 ('savings-planner','Savings planner','digital_tool',9900,false,'Planner tabungan interaktif.'),
 ('freelancer-planner','Freelancer finance planner','digital_tool',14900,false,'Perencanaan pemasukan project dan cadangan, bukan jaminan.'),
 ('goal-planner','Goal planner','digital_tool',9900,false,'Simulasi target dan alokasi.') on conflict(code) do nothing;
create table if not exists public.digital_tool_products(tool_code text primary key check(tool_code in ('budget','savings','freelancer','goal')),product_id uuid unique not null references public.products(id));
insert into public.digital_tool_products select v.tool,p.id from (values('budget','budget-planner'),('savings','savings-planner'),('freelancer','freelancer-planner'),('goal','goal-planner')) v(tool,code) join public.products p on p.code=v.code and p.type='digital_tool' on conflict do nothing;
alter table public.digital_tool_products enable row level security;
revoke all on public.digital_tool_products from public,anon,authenticated;
grant select on public.digital_tool_products to anon,authenticated;
create policy public_tool_mapping on public.digital_tool_products for select using(true);
create or replace function public.can_use_tool(p_tool text) returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and exists(select 1 from public.digital_tool_products m join public.orders o on o.product_id=m.product_id where m.tool_code=p_tool and o.user_id=auth.uid() and o.status='paid' and o.product_type='digital_tool')
$$;
create or replace function public.valid_planner_input(p_tool text,p_input jsonb) returns boolean language plpgsql immutable set search_path='' as $$
declare
 keys text[];
 k text;
 n numeric;
 minimum_value numeric;
 maximum_value numeric;
begin
 keys:=case p_tool when 'budget' then array['income','essential','wants','saving'] when 'savings' then array['target','saved','monthly','months'] when 'goal' then array['target','saved','monthly','months'] when 'freelancer' then array['projectIncome','projects','essential','reserveMonths','reserveMonthly'] else null end;
 if keys is null or p_input is null or jsonb_typeof(p_input)<>'object' or not p_input ?& keys or (select count(*) from jsonb_object_keys(p_input))<>cardinality(keys) then return false;end if;
 foreach k in array keys loop
  if jsonb_typeof(p_input->k)<>'number' then return false;end if;n:=(p_input->>k)::numeric;
  minimum_value := 0;
  maximum_value := 1000000000000;
  if k = 'months' then
   minimum_value := 1;
   maximum_value := 1200;
  elsif k = 'reserveMonths' then
   minimum_value := 1;
   maximum_value := 24;
  elsif k = 'projects' then
   maximum_value := 1000;
  end if;
  if n <> trunc(n) then
   return false;
  end if;
  if n < minimum_value or n > maximum_value then
   return false;
  end if;
 end loop;return true;
end $$;
create table if not exists public.planner_results(id uuid primary key default gen_random_uuid(),user_id uuid not null references auth.users(id) on delete cascade,tool_code text not null references public.digital_tool_products(tool_code),title text not null check(length(title) between 1 and 80),inputs jsonb not null,created_at timestamptz not null default now(),check(public.valid_planner_input(tool_code,inputs)));
alter table public.planner_results enable row level security;
revoke all on public.planner_results from public,anon,authenticated;
grant select,insert,delete on public.planner_results to authenticated;
create policy own_paid_planner on public.planner_results for all to authenticated using(user_id=auth.uid() and public.can_use_tool(tool_code)) with check(user_id=auth.uid() and public.can_use_tool(tool_code));
create or replace function public.get_tool_data(p_tool text) returns jsonb language plpgsql stable security invoker set search_path='' as $$
begin
 if not public.can_use_tool(p_tool) then raise exception 'Pesanan paid diperlukan' using errcode='42501';end if;
 return jsonb_build_object('saved',coalesce((select jsonb_agg(to_jsonb(r) order by created_at desc) from public.planner_results r where user_id=auth.uid() and tool_code=p_tool),'[]'::jsonb));
end $$;
create or replace function public.save_tool_result(p_tool text,p_title text,p_inputs jsonb) returns uuid language plpgsql security invoker set search_path='' as $$
declare saved uuid;
begin
 if not public.can_use_tool(p_tool) then raise exception 'Pesanan paid diperlukan' using errcode='42501';end if;
 insert into public.planner_results(user_id,tool_code,title,inputs) values(auth.uid(),p_tool,p_title,p_inputs) returning id into saved;return saved;
end $$;
revoke all on function public.can_use_tool(text),public.valid_planner_input(text,jsonb),public.get_tool_data(text),public.save_tool_result(text,text,jsonb) from public,anon;
grant execute on function public.can_use_tool(text),public.valid_planner_input(text,jsonb),public.get_tool_data(text),public.save_tool_result(text,text,jsonb) to authenticated;
-- Interactive tools do not require a supporting file. QRIS and manual checks stay mandatory.
create or replace function public.create_order(p_product_code text,p_request_id uuid) returns public.orders language plpgsql security definer set search_path='' as $$
declare p public.products;cfg public.payment_settings;o public.orders;new_id uuid:=gen_random_uuid();addition integer:=0;
begin
 if auth.uid() is null then raise exception 'Login diperlukan' using errcode='42501';end if;
 if p_request_id is null then raise exception 'ID permintaan diperlukan' using errcode='22023';end if;
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text,1));
 select * into o from public.orders where user_id=auth.uid() and request_id=p_request_id;if found then return o;end if;
 select * into p from public.products where code=p_product_code and active and (promo_starts_at is null or promo_starts_at<=now()) and (promo_ends_at is null or promo_ends_at>now());
 if not found then raise exception 'Produk belum tersedia' using errcode='22023';end if;
 if p.type='digital_tool' and not exists(select 1 from public.digital_tool_products where product_id=p.id) and (p.digital_file_path is null or not exists(select 1 from storage.objects where bucket_id='digital-files' and name=p.digital_file_path)) then raise exception 'File produk belum tersedia' using errcode='22023';end if;
 select * into cfg from public.payment_settings where enabled and (product_id=p.id or product_id is null) order by product_id nulls last limit 1;
 if not found then raise exception 'Pembayaran belum tersedia' using errcode='22023';end if;
 if not exists(select 1 from storage.objects where bucket_id='merchant-qris' and name=cfg.qris_path) then raise exception 'QRIS resmi belum tersedia' using errcode='22023';end if;
 if cfg.unique_amount_enabled then
  perform pg_advisory_xact_lock(hashtextextended(cfg.merchant_name,2));
  select i into addition from generate_series(1,999) i where not exists(select 1 from public.orders x where x.merchant_name=cfg.merchant_name and x.total_rupiah=p.price_rupiah+i and (x.status='submitted' or (x.status='pending' and x.expires_at>now()))) order by i limit 1;
  if addition is null then raise exception 'Nominal pencocokan belum tersedia' using errcode='22023';end if;
 end if;
 insert into public.orders(id,order_number,user_id,product_id,request_id,product_name,product_type,price_rupiah,unique_amount,total_rupiah,duration_days,plan,merchant_name,qris_path,payment_instructions,expires_at)
 values(new_id,'MB-'||to_char(now() at time zone 'Asia/Jakarta','YYMMDD')||'-'||upper(left(replace(new_id::text,'-',''),10)),auth.uid(),p.id,p_request_id,p.name,p.type,p.price_rupiah,addition,p.price_rupiah+addition,p.duration_days,p.plan,cfg.merchant_name,cfg.qris_path,cfg.instructions,now()+interval '24 hours') returning * into o;return o;
end $$;
commit;


-- ===== supabase/migrations/013_recurring_forecast.sql =====
begin;
create function public.get_forecast_analytics() returns jsonb language plpgsql stable security invoker set search_path='' as $$
declare source jsonb;txs jsonb;
begin
 source:=public.get_pro_analytics(); -- Pro + owner RLS already enforced
 select coalesce(jsonb_agg(t.value||jsonb_build_object('origin',case when exists(select 1 from public.recurring_occurrences o where o.user_id=auth.uid() and o.transaction_id=(t.value->>'id')::uuid) then 'recurring' else null end)),'[]'::jsonb) into txs from jsonb_array_elements(source->'transactions') t;
 return source||jsonb_build_object('transactions',txs,'recurring',coalesce((select jsonb_agg(to_jsonb(r)) from public.recurring_rules r where user_id=auth.uid()),'[]'::jsonb));
end $$;
revoke all on function public.get_forecast_analytics() from public,anon;
grant execute on function public.get_forecast_analytics() to authenticated;
commit;


-- ===== supabase/migrations/014_admin_login.sql =====
begin;
-- Failed logins have no verified admin identity. Existing purchase audit stays intact.

create table if not exists public.admin_login_attempts (
 id uuid primary key default gen_random_uuid(), identity_hash text not null check(identity_hash ~ '^[0-9a-f]{64}$'),
 created_at timestamptz not null default now(), finished_at timestamptz,
 outcome text check(outcome in('success','failed'))
);
alter table public.admin_login_attempts enable row level security;
revoke all on public.admin_login_attempts from public,anon,authenticated;
create index if not exists admin_login_identity_time on public.admin_login_attempts(identity_hash,created_at);
create index if not exists admin_login_created_time on public.admin_login_attempts(created_at);
create or replace function public.begin_admin_login(p_identity_hash text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare attempt uuid;
begin
 if p_identity_hash is null or p_identity_hash !~ '^[0-9a-f]{64}$' then raise exception 'Invalid attempt' using errcode='22023';end if;
 perform pg_advisory_xact_lock(hashtextextended(p_identity_hash,14));
 delete from public.admin_login_attempts where created_at<now()-interval '7 days';
 if (select count(*) from public.admin_login_attempts where identity_hash=p_identity_hash and created_at>now()-interval '15 minutes')>=5 then
  if not exists(select 1 from public.audit_logs where action='admin.login.failed' and object_id=p_identity_hash and created_at>now()-interval '15 minutes') then
   insert into public.audit_logs(admin_id,action,object_id,after_data) values(null,'admin.login.failed',p_identity_hash,jsonb_build_object('outcome','failed','reason','rate_limited'));
  end if;
  return jsonb_build_object('allowed',false);
 end if;
 insert into public.admin_login_attempts(identity_hash) values(p_identity_hash) returning id into attempt;
 return jsonb_build_object('allowed',true,'attempt_id',attempt);
end $$;
create or replace function public.finish_admin_login(p_attempt_id uuid,p_success boolean) returns void
language plpgsql security definer set search_path='' as $$
declare attempt public.admin_login_attempts;actor uuid;
begin
 select * into attempt from public.admin_login_attempts where id=p_attempt_id for update;
 if not found or attempt.created_at<now()-interval '15 minutes' or p_success is null then raise exception 'Invalid attempt' using errcode='22023';end if;
 if p_success then
  if not public.is_admin() or not exists(select 1 from auth.users u where u.id=auth.uid() and encode(sha256(convert_to(lower(btrim(u.email)),'UTF8')),'hex')=attempt.identity_hash) then
   raise exception 'Akses ditolak' using errcode='42501';
  end if;
  actor:=auth.uid();
 end if;
 if attempt.finished_at is not null then return;end if;
 update public.admin_login_attempts set finished_at=now(),outcome=case when p_success then 'success' else 'failed' end where id=attempt.id;
 insert into public.audit_logs(admin_id,action,object_id,after_data)
 values(actor,case when p_success then 'admin.login.success' else 'admin.login.failed' end,attempt.id::text,jsonb_build_object('outcome',case when p_success then 'success' else 'failed' end));
end $$;
revoke all on function public.begin_admin_login(text),public.finish_admin_login(uuid,boolean) from public;
-- Anonymous failure reports need the random, unlisted attempt capability.
-- They are attempt telemetry, not proof of identity. Success always requires verified admin JWT.
grant execute on function public.begin_admin_login(text),public.finish_admin_login(uuid,boolean) to anon,authenticated;
notify pgrst,'reload schema';
commit;


-- ===== supabase/migrations/015_support_content.sql =====
begin;
create or replace function public.valid_site_support(c jsonb) returns boolean language plpgsql immutable set search_path='' as $$
declare s jsonb;
begin
 -- Legacy content receives defaults in code until this migration is applied.
 if not c ? 'support' then return true;end if;
 s:=c->'support';
 if jsonb_typeof(s) is distinct from 'object' then return false;end if;
 if not s ?& array['phone','message','hours'] or (select count(*) from jsonb_object_keys(s))<>3 then return false;end if;
 if jsonb_typeof(s->'phone') is distinct from 'string' or (s->>'phone') !~ '^62[1-9][0-9]{7,12}$' then return false;end if;
 if jsonb_typeof(s->'message') is distinct from 'string' or length(btrim(s->>'message')) not between 1 and 300 then return false;end if;
 if jsonb_typeof(s->'hours') is distinct from 'string' or length(btrim(s->>'hours')) not between 1 and 120 then return false;end if;
 return true;
end $$;
do $$begin
 if not exists(select 1 from pg_constraint where conrelid='public.site_content_draft'::regclass and conname='draft_support_valid') then alter table public.site_content_draft add constraint draft_support_valid check(public.valid_site_support(content));end if;
 if not exists(select 1 from pg_constraint where conrelid='public.site_content_published'::regclass and conname='published_support_valid') then alter table public.site_content_published add constraint published_support_valid check(public.valid_site_support(content));end if;
end $$;
-- Only fill missing fields; never replace an admin's configured support values or publish a draft.
update public.site_content_draft set content=content||jsonb_build_object('support',jsonb_build_object('phone','6288806001355','message','Halo My Budget, saya butuh bantuan.','hours','Setiap hari, 08.00-21.00 WIB. Pesan di luar jam itu dibalas paling lambat 1x24 jam')),revision=revision+1,updated_at=now() where not content ? 'support';
update public.site_content_published set content=content||jsonb_build_object('support',jsonb_build_object('phone','6288806001355','message','Halo My Budget, saya butuh bantuan.','hours','Setiap hari, 08.00-21.00 WIB. Pesan di luar jam itu dibalas paling lambat 1x24 jam')) where not content ? 'support';
notify pgrst,'reload schema';
commit;


-- ===== supabase/migrations/016_paid_catalog.sql =====
begin;
-- Free remains in plans/subscriptions, never a purchasable product.
update public.products set active=false where price_rupiah<=0;
create or replace function public.create_order(p_product_code text,p_request_id uuid) returns public.orders language plpgsql security definer set search_path='' as $$
declare p public.products; cfg public.payment_settings; o public.orders; new_id uuid:=gen_random_uuid(); addition integer:=0;
begin
 if auth.uid() is null then raise exception 'Login diperlukan.' using errcode='42501'; end if;
 if p_request_id is null then raise exception 'ID permintaan diperlukan.' using errcode='22023'; end if;
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text,1));
 select * into o from public.orders where user_id=auth.uid() and request_id=p_request_id;if found then if o.price_rupiah<=0 then raise exception 'Produk gratis tidak dapat dibeli.' using errcode='22023';end if;return o; end if;
 select * into p from public.products where code=p_product_code and active and (promo_starts_at is null or promo_starts_at<=now()) and (promo_ends_at is null or promo_ends_at>now());
 if found and p.price_rupiah<=0 then raise exception 'Produk gratis tidak dapat dibeli.' using errcode='22023';end if;
 if not found then raise exception 'Produk belum tersedia.' using errcode='22023'; end if;
 if p.type='digital_tool' and not exists(select 1 from public.digital_tool_products where product_id=p.id) and (p.digital_file_path is null or not exists(select 1 from storage.objects where bucket_id='digital-files' and name=p.digital_file_path)) then raise exception 'File produk belum tersedia.' using errcode='22023'; end if;
 select * into cfg from public.payment_settings where enabled and (product_id=p.id or product_id is null) order by product_id nulls last limit 1;
 if not found then raise exception 'Pembayaran belum tersedia. QRIS merchant resmi belum dikonfigurasi.' using errcode='22023'; end if;
 if not exists(select 1 from storage.objects where bucket_id='merchant-qris' and name=cfg.qris_path) then raise exception 'Pembayaran belum tersedia. Aset QRIS belum tersedia.' using errcode='22023'; end if;
 if cfg.unique_amount_enabled then
  perform pg_advisory_xact_lock(hashtextextended(cfg.merchant_name,2));
  select i into addition from generate_series(1,999) i where not exists(select 1 from public.orders x where x.merchant_name=cfg.merchant_name and x.total_rupiah=p.price_rupiah+i and (x.status='submitted' or (x.status='pending' and x.expires_at>now()))) order by i limit 1;
  if addition is null then raise exception 'Nominal pencocokan belum tersedia. Coba lagi nanti.' using errcode='22023'; end if;
 end if;
 insert into public.orders(id,order_number,user_id,product_id,request_id,product_name,product_type,price_rupiah,unique_amount,total_rupiah,duration_days,plan,merchant_name,qris_path,payment_instructions,expires_at)
 values(new_id,'MB-'||to_char(now() at time zone 'Asia/Jakarta','YYMMDD')||'-'||upper(left(replace(new_id::text,'-',''),10)),auth.uid(),p.id,p_request_id,p.name,p.type,p.price_rupiah,addition,p.price_rupiah+addition,p.duration_days,p.plan,cfg.merchant_name,cfg.qris_path,cfg.instructions,now()+interval '24 hours') returning * into o;return o;
end $$;
create or replace function public.reject_free_order() returns trigger language plpgsql set search_path='' as $$ begin if new.price_rupiah<=0 or new.total_rupiah<=0 then raise exception 'Produk gratis tidak dapat dibeli.' using errcode='22023';end if;return new;end $$;

create trigger paid_order_only before insert on public.orders for each row execute function public.reject_free_order();
notify pgrst,'reload schema';
commit;


-- ===== supabase/migrations/017_order_reviews.sql =====
begin;
-- Keep unverified legacy reviews privately; paid-order reviews require moderation.
alter table public.reviews add column if not exists order_id uuid unique references public.orders(id);
alter table public.reviews add column if not exists product_id uuid references public.products(id);
-- Existing body API remains compatible; comment is the database text projection.
alter table public.reviews add column if not exists comment text generated always as (body) stored;
alter table public.reviews add column if not exists status text not null default 'hidden' check(status in ('pending','approved','hidden'));
create table if not exists public.review_attempts(user_id uuid primary key references auth.users(id) on delete cascade, attempted_at timestamptz not null);
alter table public.review_attempts enable row level security;
revoke all on public.review_attempts from public,anon,authenticated;
create policy review_read on public.reviews for select to authenticated using(user_id=auth.uid() or public.is_admin());
revoke all on public.reviews from public,anon,authenticated;
grant select on public.reviews to authenticated;
-- Writes only through checked RPCs; clients cannot approve, move ownership or bypass rate limits.
create or replace function public.save_order_review(p_order_id uuid,p_rating integer,p_comment text,p_display_name text) returns public.reviews
language plpgsql security definer set search_path='' as $$
declare o public.orders;r public.reviews;t timestamptz;
begin
 if auth.uid() is null then raise exception 'Login diperlukan.' using errcode='42501';end if;
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text,77));
 select * into o from public.orders where id=p_order_id and user_id=auth.uid() and status='paid' and price_rupiah>0;
 if not found then raise exception 'Hanya pemilik pesanan terverifikasi yang dapat memberi ulasan.' using errcode='42501';end if;
 if p_rating is null or p_rating not between 1 and 5 or p_comment is null or length(btrim(p_comment)) not between 10 and 500 or p_display_name is null or length(btrim(p_display_name)) not between 2 and 60 then raise exception 'Periksa rating, komentar (10–500), dan nama (2–60).' using errcode='22023';end if;
 if p_comment ~ '[<>]' or p_display_name ~ '[<>]' then raise exception 'Gunakan teks biasa tanpa HTML.' using errcode='22023';end if;
 select attempted_at into t from public.review_attempts where user_id=auth.uid();
 if t>now()-interval '30 seconds' then raise exception 'Tunggu 30 detik sebelum mengirim lagi.' using errcode='P0001';end if;
 insert into public.review_attempts values(auth.uid(),now()) on conflict(user_id) do update set attempted_at=excluded.attempted_at;
 insert into public.reviews(user_id,order_id,product_id,rating,body,display_name,status) values(auth.uid(),o.id,o.product_id,p_rating,btrim(p_comment),btrim(p_display_name),'pending')
 on conflict(order_id) do update set rating=excluded.rating,body=excluded.body,display_name=excluded.display_name,status='pending',updated_at=now() where reviews.user_id=auth.uid() returning * into r;
 return r;
end $$;
create or replace function public.moderate_review(p_id uuid,p_action text) returns void language plpgsql security definer set search_path='' as $$
declare r public.reviews;
begin
 if not public.is_admin() then raise exception 'Akses ditolak.' using errcode='42501';end if;
 if p_action not in ('approved','hidden','delete') or p_action is null then raise exception 'Aksi tidak valid.' using errcode='22023';end if;
 select * into r from public.reviews where id=p_id for update;
 if not found then raise exception 'Ulasan tidak ditemukan.' using errcode='22023';end if;
 if p_action='approved' and (r.order_id is null or not exists(select 1 from public.orders where id=r.order_id and user_id=r.user_id and product_id=r.product_id and status='paid')) then raise exception 'Ulasan tidak terhubung ke pembelian terverifikasi.' using errcode='22023';end if;
 if p_action='delete' then delete from public.reviews where id=p_id;else update public.reviews set status=p_action where id=p_id;end if;
 insert into public.audit_logs(admin_id,action,object_id,before_data,after_data) values(auth.uid(),'review.'||p_action,p_id::text,to_jsonb(r),jsonb_build_object('status',p_action));
end $$;
-- Fixed public projection: no user_id, order_id, email or financial data.
create or replace function public.get_order_review(p_order_id uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not exists(select 1 from public.orders where id=p_order_id and user_id=auth.uid() and status='paid') then raise exception 'Pesanan belum terverifikasi atau bukan milikmu.' using errcode='42501';end if;
 return (select to_jsonb(r) from public.reviews r where r.order_id=p_order_id and r.user_id=auth.uid());
end $$;
revoke all on function public.get_order_review(uuid) from public,anon;
grant execute on function public.get_order_review(uuid) to authenticated;
create or replace function public.list_public_reviews(p_limit integer default 20) returns table(id uuid,display_name text,rating smallint,body text,created_at timestamptz,updated_at timestamptz) language sql stable security definer set search_path='' as $$
 select r.id,r.display_name,r.rating,r.body,r.created_at,r.updated_at from public.reviews r where r.status='approved' and r.order_id is not null order by r.created_at desc,r.id desc limit least(100,greatest(1,coalesce(p_limit,20)));
$$;
create or replace function public.review_summary() returns table(total bigint,average numeric,counts bigint[]) language sql stable security definer set search_path='' as $$
 select count(*),coalesce(round(avg(rating),1),0),array[count(*) filter(where rating=1),count(*) filter(where rating=2),count(*) filter(where rating=3),count(*) filter(where rating=4),count(*) filter(where rating=5)] from public.reviews where status='approved' and order_id is not null;
$$;
revoke all on function public.save_order_review(uuid,integer,text,text),public.moderate_review(uuid,text) from public,anon;
grant execute on function public.save_order_review(uuid,integer,text,text),public.moderate_review(uuid,text) to authenticated;
create or replace function public.list_public_reviews_page(p_offset integer default 0) returns table(id uuid,display_name text,rating smallint,body text,created_at timestamptz,updated_at timestamptz) language sql stable security definer set search_path='' as $$
 select r.id,r.display_name,r.rating,r.body,r.created_at,r.updated_at from public.reviews r where r.status='approved' and r.order_id is not null order by r.created_at desc,r.id desc limit 10 offset greatest(0,least(coalesce(p_offset,0),100000));
$$;
revoke all on function public.list_public_reviews_page(integer) from public;
grant execute on function public.list_public_reviews_page(integer) to anon,authenticated;
notify pgrst,'reload schema';
commit;


-- ===== supabase/migrations/018_rounding_receipts.sql =====
begin;
create table if not exists public.finance_preferences (
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

create table if not exists public.receipt_files (
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


-- ===== supabase/migrations/019_monthly_reports.sql =====
begin;
create function public.assert_report_window(p_from date,p_to date) returns void language plpgsql stable security definer set search_path='' as $$
declare n integer;first_month date:=date_trunc('month',now() at time zone 'Asia/Jakarta')::date;begin
 if auth.uid() is null then raise exception 'Login diperlukan' using errcode='42501';end if;
 select report_range_months into n from public.finance_preferences where user_id=auth.uid();n:=coalesce(n,3);
 if p_from is null or p_to is null or p_from>p_to or p_from<(first_month-make_interval(months=>n-1))::date or p_to>=(first_month+interval '1 month')::date then raise exception 'Periode di luar rentang laporan akun (3/6 bulan terakhir)' using errcode='22023';end if;
end $$;
create function public.get_monthly_report() returns jsonb language plpgsql stable security invoker set search_path='' as $$
declare n integer;first_month date:=date_trunc('month',now() at time zone 'Asia/Jakarta')::date;start_date date;rows jsonb;begin
 if auth.uid() is null or not (public.get_entitlement()->>'reports_access')::boolean then raise exception 'Laporan memerlukan Premium aktif' using errcode='42501';end if;
 select report_range_months into n from public.finance_preferences where user_id=auth.uid();n:=coalesce(n,3);start_date:=(first_month-make_interval(months=>n-1))::date;
 if (select count(*) from public.transactions where user_id=auth.uid() and (data->>'date')::date>=start_date)>50000 then raise exception 'Laporan melebihi 50.000 transaksi. Hubungi bantuan.' using errcode='22023';end if;
 select coalesce(jsonb_agg(data||jsonb_build_object('id',id,'amount',amount_rounded,'amount_original',amount_original,'rounding_difference',rounding_difference,'receipt_path',receipt_path) order by data->>'date',id),'[]'::jsonb) into rows from public.transactions where user_id=auth.uid() and (data->>'date')::date>=start_date and (data->>'date')::date<(first_month+interval '1 month')::date;
 return jsonb_build_object('range',n,'current',to_char(first_month,'YYYY-MM'),'transactions',rows);
end $$;
-- Legacy report endpoint is bounded too; an older selected month cannot shift the window.
create or replace function public.get_report_transactions(p_month text) returns table(id uuid,data jsonb) language plpgsql stable security invoker set search_path='' as $$
declare d date;n integer;first_month date:=date_trunc('month',now() at time zone 'Asia/Jakarta')::date;begin
 if not (public.get_entitlement()->>'reports_access')::boolean then raise exception 'Premium aktif diperlukan' using errcode='42501';end if;
 if p_month is null or p_month !~ '^\d{4}-(0[1-9]|1[0-2])$' then raise exception 'Bulan tidak valid' using errcode='22023';end if;
 d:=(p_month||'-01')::date;perform public.assert_report_window(d,d);
 select report_range_months into n from public.finance_preferences where user_id=auth.uid();
 return query select t.id,t.data from public.transactions t where t.user_id=auth.uid() and (t.data->>'date')::date>=(first_month-make_interval(months=>coalesce(n,3)-1))::date and (t.data->>'date')::date<(d+interval '1 month')::date order by t.data->>'date',t.id;
end $$;
create or replace function public.get_advanced_report_data(p_from date,p_to date,p_compare_from date,p_compare_to date) returns jsonb language plpgsql stable security invoker set search_path='' as $$
declare result jsonb;begin
 if auth.uid() is null or public.get_effective_plan() is distinct from 'pro' then raise exception 'Pro aktif diperlukan' using errcode='42501';end if;
 perform public.assert_report_window(p_from,p_to);perform public.assert_report_window(p_compare_from,p_compare_to);
 if greatest(p_to,p_compare_to)>(now() at time zone 'Asia/Jakarta')::date then raise exception 'Tanggal di masa depan' using errcode='22023';end if;
 if (select count(*) from public.transactions where user_id=auth.uid() and ((data->>'date')::date between p_from and p_to or (data->>'date')::date between p_compare_from and p_compare_to))>50000 then raise exception 'Maksimum 50.000 transaksi' using errcode='22023';end if;
 select coalesce(jsonb_agg(data||jsonb_build_object('id',id)),'[]'::jsonb) into result from public.transactions where user_id=auth.uid() and ((data->>'date')::date between p_from and p_to or (data->>'date')::date between p_compare_from and p_compare_to);return result;
end $$;
revoke all on function public.assert_report_window(date,date),public.get_monthly_report() from public,anon;
grant execute on function public.assert_report_window(date,date),public.get_monthly_report() to authenticated;
notify pgrst,'reload schema';
commit;


-- ===== supabase/migrations/020_nullable_receipt_json.sql =====
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


-- ===== supabase/migrations/021_private_receipts.sql =====
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
create policy receipt_read on storage.objects
 for select to authenticated
 using(bucket_id='receipts' and (storage.foldername(name))[1]=auth.uid()::text);
create policy receipt_insert on storage.objects
 for insert to authenticated
 with check(bucket_id='receipts'
  and (storage.foldername(name))[1]=auth.uid()::text
  and exists(select 1 from public.receipt_files f
   where f.path=name and f.user_id=auth.uid() and not f.retiring));
create policy receipt_delete on storage.objects
 for delete to authenticated
 using(bucket_id='receipts' and (storage.foldername(name))[1]=auth.uid()::text);

-- Restrictive guard also blocks any other permissive policy from widening
-- receipt access to another user's folder.
create policy receipt_owner_guard on storage.objects
 as restrictive for all to public
 using(bucket_id<>'receipts' or (storage.foldername(name))[1]=auth.uid()::text)
 with check(bucket_id<>'receipts' or (storage.foldername(name))[1]=auth.uid()::text);

notify pgrst,'reload schema';
commit;


-- ===== supabase/migrations/022_receipt_cleanup_storage_api.sql =====
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

-- ===== supabase/migrations/023_review_photos.sql =====
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


