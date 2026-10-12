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
