import {authenticatedClient,apiError,privateJson} from '@/lib/server-api';
import {validUpload} from '@/lib/product-validation';
import {z} from 'zod';
async function cleanup(c:Awaited<ReturnType<typeof authenticatedClient>>){
 const q=await c.rpc('claim_receipt_cleanup');if(q.error)throw new Error('Cleanup belum tersedia.');
 let pending=0;for(const path of q.data||[]){const r=await c.storage.from('receipts').remove([path]);if(r.error){pending++;continue;}const ack=await c.rpc('ack_receipt_cleanup',{p_path:path});if(ack.error)pending++;}return pending;
}
export async function GET(request:Request){try{const c=await authenticatedClient(request),id=z.string().uuid().safeParse(new URL(request.url).searchParams.get('transaction'));if(!id.success)return privateJson({error:'Transaksi tidak valid.'},400);const r=await c.from('transactions').select('receipt_path').eq('id',id.data).maybeSingle();if(r.error||!r.data?.receipt_path)return privateJson({error:'Struk tidak ditemukan.'},404);const signed=await c.storage.from('receipts').createSignedUrl(r.data.receipt_path,120);if(signed.error)return privateJson({error:'Struk belum dapat dibuka.'},503);return privateJson({url:signed.data.signedUrl});}catch(e){return apiError(e);}}
export async function POST(request:Request){try{
 const c=await authenticatedClient(request);
 if(request.headers.get('content-type')?.includes('application/json'))return privateJson({pending:await cleanup(c)});
 if(Number(request.headers.get('content-length')||0)>2300000)return privateJson({error:'Struk maksimal 2 MB setelah kompresi.'},413);
 const form=await request.formData(),id=z.string().uuid().safeParse(form.get('transaction_id')),file=form.get('file');
 if(!id.success||!(file instanceof File)||file.size>2097152||!['image/jpeg','image/png','image/webp'].includes(file.type))return privateJson({error:'Pilih JPG, PNG, atau WebP maksimal 2 MB.'},400);
 const bytes=new Uint8Array(await file.arrayBuffer());if(!validUpload(bytes,file.type,'receipts'))return privateJson({error:'Isi gambar tidak valid.'},400);
 const auth=await c.auth.getUser(request.headers.get('authorization')!.slice(7));if(!auth.data.user)return privateJson({error:'Masuk kembali.'},401);
 const path=`${auth.data.user.id}/${id.data}/${crypto.randomUUID()}.${file.type==='image/jpeg'?'jpg':file.type==='image/png'?'png':'webp'}`;
 const registered=await c.from('receipt_files').insert({path,user_id:auth.data.user.id,transaction_id:id.data});if(registered.error)return privateJson({error:'Struk gagal didaftarkan. Periksa migration 018.'},503);
 const result=await c.storage.from('receipts').upload(path,bytes,{contentType:file.type,upsert:false});if(result.error)return privateJson({error:'Upload gagal. Metadata sementara akan dibersihkan otomatis saat aplikasi dibuka setelah 24 jam.'},503);
 return privateJson({path});
 }catch(e){return apiError(e);}}
