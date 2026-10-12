import {adminClient,adminError} from '@/lib/admin-server';
import {privateJson} from '@/lib/server-api';
import {z} from 'zod';
export async function POST(request:Request){try{const c=await adminClient(request),v=z.object({user_id:z.string().uuid(),months:z.union([z.literal(3),z.literal(6)])}).strict().safeParse(await request.json());if(!v.success)return privateJson({error:'Pilih ID pengguna yang valid dan 3 atau 6 bulan.'},400);const r=await c.rpc('admin_set_report_range',{p_user_id:v.data.user_id,p_months:v.data.months});if(r.error)return privateJson({error:'Pengaturan gagal; periksa ID pengguna.'},400);return privateJson({ok:true});}catch(e){return adminError(e);}}
