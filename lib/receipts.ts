import {supabase} from './supabase';
export async function compressReceipt(file:File){
 if(!['image/jpeg','image/png','image/webp'].includes(file.type)||file.size>10*1024*1024)throw new Error('Pilih JPG, PNG, atau WebP maksimal 10 MB.');
 const bitmap=await createImageBitmap(file);try{
  if(bitmap.width*bitmap.height>50000000)throw new Error('Resolusi gambar terlalu besar.');
  const scale=Math.min(1,1280/Math.max(bitmap.width,bitmap.height)),canvas=document.createElement('canvas');canvas.width=Math.max(1,Math.round(bitmap.width*scale));canvas.height=Math.max(1,Math.round(bitmap.height*scale));
  const ctx=canvas.getContext('2d');if(!ctx)throw new Error('Kompresi gambar tidak tersedia.');ctx.drawImage(bitmap,0,0,canvas.width,canvas.height);
  const blob=await new Promise<Blob>((resolve,reject)=>canvas.toBlob(v=>v?resolve(v):reject(new Error('Gambar gagal dikompres.')),'image/webp',0.7));
  if(blob.size>2097152)throw new Error('Gambar masih lebih dari 2 MB. Pilih gambar lebih kecil.');return blob;
 }finally{bitmap.close();}
}
export async function uploadReceipt(blob:Blob,id:string){
 if(!supabase)throw new Error('Supabase belum tersedia.');const {data:{session}}=await supabase.auth.getSession();if(!session)throw new Error('Masuk kembali.');
 const form=new FormData();form.set('transaction_id',id);form.set('file',blob,'receipt.webp');const r=await fetch('/api/receipts',{method:'POST',headers:{Authorization:`Bearer ${session.access_token}`},body:form});const data=await r.json();if(!r.ok)throw new Error(data.error||'Upload gagal.');return data.path as string;
}
