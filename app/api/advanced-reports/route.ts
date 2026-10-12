import {authenticatedClient,privateJson,apiError} from '@/lib/server-api';import {advancedReport,advancedReportCsv} from '@/lib/finance/advanced-reports';import {z} from 'zod';
const date=z.string().regex(/^\d{4}-\d{2}-\d{2}$/).refine(v=>!isNaN(Date.parse(v))&&new Date(v).toISOString().slice(0,10)===v);
const query=z.object({from:date,to:date,compare_from:date,compare_to:date,format:z.enum(['json','csv']).default('json')}).strict();
export async function GET(request:Request){try{
 const c=await authenticatedClient(request),parsed=query.safeParse(Object.fromEntries(new URL(request.url).searchParams));
 if(!parsed.success)return privateJson({error:'Pilih empat tanggal yang valid.'},400);
 const p=parsed.data,r=await c.rpc('get_advanced_report_data',{p_from:p.from,p_to:p.to,p_compare_from:p.compare_from,p_compare_to:p.compare_to});
 if(r.error)return privateJson({error:r.error.code==='42501'?'Pro aktif diperlukan.':r.error.code==='22023'?'Periksa periode: harus dalam rentang akun 3/6 bulan terakhir, tidak melewati hari ini, dan maksimal 50.000 transaksi.':'Periksa migration 011 dan koneksi.'},r.error.code==='42501'?403:r.error.code==='22023'?400:503);
 const report=advancedReport(r.data,{from:p.from,to:p.to},{from:p.compare_from,to:p.compare_to});
 if(p.format==='csv')return new Response(advancedReportCsv(report),{headers:{'Content-Type':'text/csv; charset=utf-8','Content-Disposition':`attachment; filename="mybudget-report-${p.from}-${p.to}.csv"`,'Cache-Control':'private, no-store','Vary':'Authorization'}});
 return privateJson(report);
}catch(e){return apiError(e);}}
