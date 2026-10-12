import { supabase } from './supabase';
import {orderApi} from './order-api';
async function cleanupReceipts(){try{const r=await orderApi('/api/receipts',{cleanup:true});return r.pending?'Data tersimpan; penghapusan struk lama menunggu koneksi.':null;}catch{return 'Data tersimpan; struk lama akan dicoba dibersihkan saat aplikasi dibuka lagi.';}}
import { type Profile, type Transaction, type Budget, type Goal } from './finance';
export type Data = { profile: Profile | null; transactions: Transaction[]; budgets: Budget[]; goals: Goal[] };
export const empty: Data = { profile:null,transactions:[],budgets:[],goals:[] };
export const categories = ['Makan & minum','Transportasi','Belanja','Tagihan','Kesehatan','Hiburan','Lainnya','Project','Gaji'];
export async function loadData(user: string): Promise<Data> {
 if(!supabase || user==='demo') return JSON.parse(localStorage.getItem('mybudget-demo') || JSON.stringify(empty));
 void cleanupReceipts();
 const recurring=await supabase.rpc('apply_recurring');
 if(recurring.error&&!['42501','PGRST202'].includes(recurring.error.code))throw new Error('Pencatatan berulang belum selesai; periksa koneksi lalu buka ulang aplikasi.');
 const results=await Promise.all(['profiles','transactions','budgets','goals'].map(table=>supabase!.from(table).select('*').eq('user_id',user)));
 for(const r of results) if(r.error) throw r.error;
 const ledger=await supabase.from('recurring_occurrences').select('transaction_id').eq('user_id',user);
 if(ledger.error&&!['42P01','PGRST205'].includes(ledger.error.code))throw new Error('Asal transaksi belum dapat diperiksa.');
 const generated=new Set((ledger.data||[]).map(r=>r.transaction_id));
 return {profile:results[0].data?.[0]?.data || null,transactions:(results[1].data||[]).map(r=>({...r.data,id:r.id,origin:generated.has(r.id)?'recurring':undefined})),budgets:(results[2].data||[]).map(r=>({...r.data,id:r.id})),goals:(results[3].data||[]).map(r=>({...r.data,id:r.id}))};
}
export async function saveItem(user:string,table:'profiles'|'transactions'|'budgets'|'goals',item:Profile|Transaction|Budget|Goal) {
 if(!supabase || user==='demo') return;
 const row: { user_id: string; data: Profile|Transaction|Budget|Goal; id?: string }=table==='profiles'?{user_id:user,data:item}:{id:(item as Transaction).id,user_id:user,data:item};
 const {error}=await supabase.from(table).upsert(row);if(error)throw error;
 if(table==='transactions')return cleanupReceipts();
}
export async function deleteItem(user:string,table:string,id:string){if(!supabase||user==='demo')return;const {error}=await supabase.from(table).delete().eq('id',id).eq('user_id',user);if(error)throw error;if(table==='transactions')return cleanupReceipts();}
