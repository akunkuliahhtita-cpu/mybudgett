import {authenticatedClient,apiError,privateJson} from '@/lib/server-api';
import {monthlyReport,monthlyCsv,reportMonths} from '@/lib/finance/monthly';
import type {Transaction} from '@/lib/finance';
import {monthlyPdf} from '@/lib/monthly-pdf';
import {z} from 'zod';
export const runtime='nodejs';
const schema=z.object({month:z.string().regex(/^(all|\d{4}-(0[1-9]|1[0-2]))$/).default('all'),months:z.coerce.number().refine(n=>n===3||n===6).optional(),format:z.enum(['json','pdf','csv']).default('json')}).strict();
export async function GET(request:Request){try{
 const c=await authenticatedClient(request),v=schema.safeParse(Object.fromEntries(new URL(request.url).searchParams));if(!v.success)return privateJson({error:'Pilih bulan, rentang, dan format yang valid.'},400);
 const r=await c.rpc('get_monthly_report');if(r.error)return privateJson({error:r.error.code==='42501'?'Laporan memerlukan Premium aktif.':r.error.code==='22023'?r.error.message:'Laporan belum tersedia. Periksa migration 018–019.'},r.error.code==='42501'?403:r.error.code==='22023'?400:503);
 const allowed=r.data.range as number,n=v.data.months??allowed;if(n>allowed)return privateJson({error:'Rentang melebihi izin akun.'},403);
 const months=reportMonths(r.data.current,n);if(v.data.month!=='all'&&!months.includes(v.data.month))return privateJson({error:'Bulan di luar rentang laporan akun.'},403);
 const all=monthlyReport(r.data.transactions as Transaction[],months),reports=v.data.month==='all'?all:all.filter(m=>m.month===v.data.month);
 const filename=`laporan-mybudget-${v.data.month==='all'?`${months[0]}_${months.at(-1)}`:v.data.month}`;
 if(v.data.format==='json')return privateJson({allowed,months,reports,expires_at:null});
 const content=v.data.format==='csv'?monthlyCsv(reports):new Uint8Array(await monthlyPdf(reports));
 return new Response(content,{headers:{'Content-Type':v.data.format==='pdf'?'application/pdf':'text/csv; charset=utf-8','Content-Disposition':`attachment; filename="${filename}.${v.data.format}"`,'Cache-Control':'private, no-store','Vary':'Authorization','X-Content-Type-Options':'nosniff'}});
 }catch(e){return apiError(e);}}
