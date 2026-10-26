'use client';
import {useEffect,useRef,useState} from 'react';
import Image from 'next/image';
import {ImagePlus,Star,Trash2,Upload} from 'lucide-react';
import {orderApi} from '@/lib/order-api';
import {supabase} from '@/lib/supabase';
import {reviewSchema} from '@/lib/reviews';
import {compressReviewPhoto,REVIEW_PHOTO_MAX_BYTES,REVIEW_PHOTO_MAX_ORIGINAL} from '@/lib/review-photos';
type Photo={id:string;path:string;size_bytes:number;url:string|null};
type Draft={name:string;body:string;rating:number};
const chips=['Sangat membantu','Mudah dipakai','Perlu perbaikan'];
const hints='Ceritakan pengalamanmu: apa yang paling membantu?\nBagaimana kemudahan pemakaiannya?\nApa yang bisa diperbaiki?';

function xhrUpload(file:Blob,path:string,token:string,onProgress:(value:number)=>void){
 return new Promise<void>((resolve,reject)=>{
  const url=process.env.NEXT_PUBLIC_SUPABASE_URL,key=process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
  if(!url||!key){reject(new Error('Koneksi Supabase belum dikonfigurasi.'));return;}
  const xhr=new XMLHttpRequest();xhr.open('POST',`${url}/storage/v1/object/review-photos/${path.split('/').map(encodeURIComponent).join('/')}`);
  xhr.setRequestHeader('apikey',key);xhr.setRequestHeader('Authorization',`Bearer ${token}`);xhr.setRequestHeader('Content-Type',file.type||'image/webp');xhr.setRequestHeader('x-upsert','false');
  xhr.upload.onprogress=e=>{if(e.lengthComputable)onProgress(Math.round(e.loaded/e.total*100));};
  xhr.onerror=()=>reject(new Error('Unggah terputus. Periksa koneksi lalu coba lagi.'));
  xhr.onload=()=>{if(xhr.status>=200&&xhr.status<300){onProgress(100);resolve();}else{let message='Foto gagal diunggah.';try{message=JSON.parse(xhr.responseText).message||message;}catch{}reject(new Error(message));}};
  xhr.send(file);
 });
}

export default function OrderReview({order}:{order:string}){
 const [name,setName]=useState(''),[body,setBody]=useState(''),[rating,setRating]=useState(0),[status,setStatus]=useState(''),[error,setError]=useState(''),[loading,setLoading]=useState(true),[busy,setBusy]=useState(false),[photos,setPhotos]=useState<Photo[]>([]),[staged,setStaged]=useState<{id:string;file:File;url:string}[]>([]),[progress,setProgress]=useState<Record<string,number>>({});
 const key=`mybudget-review-draft-${order}`,hydrated=useRef(false),stagedRef=useRef(staged);stagedRef.current=staged;
 useEffect(()=>{let alive=true;void (async()=>{try{const r=await orderApi(`/api/reviews?order=${order}`);if(!alive)return;let draft:Draft|null=null;try{draft=JSON.parse(localStorage.getItem(key)||'null');}catch{}
  if(r.review){setName(draft?.name??r.review.display_name);setBody(draft?.body??r.review.body);setRating(draft?.rating??r.review.rating);setStatus(r.review.status);setPhotos(r.photos||[]);}
  else{setName(draft?.name||'');setBody(draft?.body||'');setRating(draft?.rating||0);if(!draft&&supabase){const u=await supabase.auth.getUser();const p=await supabase.from('profiles').select('data').eq('user_id',u.data.user?.id||'').maybeSingle();if(alive)setName(p.data?.data?.name||'');}}
 }catch(e){if(alive)setError((e as Error).message);}finally{if(alive){hydrated.current=true;setLoading(false);}}})();return()=>{alive=false;};},[order,key]);
 useEffect(()=>{if(!hydrated.current)return;try{localStorage.setItem(key,JSON.stringify({name,body,rating} satisfies Draft));}catch{}},[key,name,body,rating]);
 useEffect(()=>()=>stagedRef.current.forEach(p=>URL.revokeObjectURL(p.url)),[]);
 async function choose(files:FileList|null){if(!files)return;setError('');const selected=Array.from(files);if(photos.length+staged.length+selected.length>3){setError('Maksimal 3 foto untuk satu ulasan.');return;}
  const next=[] as typeof staged;for(const file of selected){if(!['image/jpeg','image/png','image/webp'].includes(file.type)){setError('Foto harus JPG, PNG, atau WebP.');continue;}if(file.size>REVIEW_PHOTO_MAX_ORIGINAL){setError(`${file.name}: ukuran foto asli maksimal 5 MB.`);continue;}next.push({id:crypto.randomUUID(),file,url:URL.createObjectURL(file)});}setStaged(v=>[...v,...next]);}
 function addChip(value:string){const sentence=`${value}.`;setBody(v=>v.trim()?`${v.trim()} ${sentence}`:sentence);}
 async function removePhoto(photo:Photo){if(!supabase)return;setError('');try{const removed=await supabase.storage.from('review-photos').remove([photo.path]);if(removed.error)throw new Error('Foto gagal dihapus. Coba lagi.');const row=await supabase.from('review_photos').delete().eq('id',photo.id);if(row.error)throw new Error('Foto sudah tidak tersimpan, tetapi data foto belum dapat diperbarui.');setPhotos(v=>v.filter(p=>p.id!==photo.id));}catch(e){setError((e as Error).message);}}
 async function save(e:React.FormEvent){e.preventDefault();setError('');const v=reviewSchema.safeParse({display_name:name,body,rating});if(!v.success){setError(v.error.issues[0].message);return;}if(!supabase){setError('Koneksi Supabase belum dikonfigurasi.');return;}setBusy(true);try{
  const saved=await orderApi('/api/reviews',{order_id:order,...v.data});setStatus('pending');let latest=[...photos];
  if(staged.length){const {data:{session}}=await supabase.auth.getSession();const {data:{user}}=await supabase.auth.getUser();if(!session||!user)throw new Error('Sesi masuk berakhir. Masuk kembali sebelum mengunggah foto.');
   for(const item of staged){const blob=await compressReviewPhoto(item.file);if(blob.size>=REVIEW_PHOTO_MAX_BYTES)throw new Error('Hasil kompresi melewati 300 KB. Pilih foto lain.');const path=`${user.id}/${saved.review.id}/${crypto.randomUUID()}.webp`;setProgress(p=>({...p,[item.id]:0}));await xhrUpload(blob,path,session.access_token,p=>setProgress(v=>({...v,[item.id]:p})));
    const record=await supabase.from('review_photos').insert({review_id:saved.review.id,user_id:user.id,path,mime_type:'image/webp',size_bytes:blob.size}).select('id,path,size_bytes').single();
    if(record.error){await supabase.storage.from('review-photos').remove([path]);throw new Error('Foto terunggah tetapi belum dapat dikaitkan ke ulasan. Coba unggah kembali.');}const signed=await supabase.storage.from('review-photos').createSignedUrl(path,600);const photo={...record.data,url:signed.data?.signedUrl||null};latest=[...latest,photo];setPhotos(v=>[...v,photo]);setStaged(v=>v.filter(x=>x.id!==item.id));URL.revokeObjectURL(item.url);setProgress(v=>{const n={...v};delete n[item.id];return n;});
   }
  }
  setPhotos(latest);setStaged([]);setProgress({});localStorage.removeItem(key);setStatus('pending');
 }catch(e){setError((e as Error).message||'Ulasan belum dapat dikirim. Coba lagi.');}finally{setBusy(false);}}
 const photoCount=photos.length+staged.length;
 return <section className="panel review-form-panel"><h2>Beri Ulasan</h2><p className="muted">Satu ulasan per pesanan. Nama boleh disamarkan. Ulasan dan foto diperiksa admin sebelum tampil publik.</p>
 {loading?<p role="status">Memuat ulasan…</p>:<form className="form" onSubmit={save}>
  <fieldset><legend>Rating (wajib)</legend><div className="rating-picker">{[1,2,3,4,5].map(n=><button key={n} type="button" aria-label={`${n} bintang`} aria-pressed={rating===n} className={n<=rating?'filled':''} onClick={()=>setRating(n)}><Star size={32} fill={n<=rating?'currentColor':'none'}/></button>)}</div></fieldset>
  <label>Nama tampilan<input required minLength={2} maxLength={60} value={name} onChange={e=>setName(e.target.value)} placeholder="Ak***a"/></label>
  <label>Komentar<textarea required minLength={10} maxLength={500} value={body} onChange={e=>setBody(e.target.value)} rows={5} placeholder={hints}/><small>{body.length}/500 · Jangan tulis data pribadi atau informasi keuangan.</small></label>
  <div className="review-chips" aria-label="Pilihan kalimat cepat">{chips.map(c=><button type="button" key={c} className="button secondary" onClick={()=>addChip(c)}>{c}</button>)}</div>
  <fieldset><legend>Foto (opsional, maksimal 3)</legend><label className="review-photo-pick"><ImagePlus size={20}/> Tambahkan foto<input type="file" accept="image/jpeg,image/png,image/webp" multiple disabled={photoCount>=3||busy} onChange={e=>{void choose(e.target.files);e.currentTarget.value='';}}/></label><small>JPG, PNG, WebP · file asli maksimal 5 MB · otomatis dikompres WebP hingga 300 KB.</small>
   {(photos.length>0||staged.length>0)&&<div className="review-photo-grid">{photos.map(p=><div className="review-photo-card" key={p.id}>{p.url&&<Image src={p.url} alt="Foto ulasan" width={92} height={92} loading="lazy" unoptimized/>}<button type="button" aria-label="Hapus foto" onClick={()=>void removePhoto(p)} disabled={busy}><Trash2 size={16}/></button></div>)}{staged.map(p=><div className="review-photo-card" key={p.id}><Image src={p.url} alt="Pratinjau foto" width={92} height={92} unoptimized/><button type="button" aria-label="Hapus foto" onClick={()=>{URL.revokeObjectURL(p.url);setStaged(v=>v.filter(x=>x.id!==p.id));}} disabled={busy}><Trash2 size={16}/></button>{progress[p.id]!==undefined&&<div className="review-upload-progress" role="status"><Upload size={13}/><progress max="100" value={progress[p.id]}/><span>{progress[p.id]}%</span></div>}</div>)}</div>}
  </fieldset>
  <button className="button primary" disabled={busy||rating===0}>{busy?'Mengirim ulasan…':status?'Perbarui ulasan':'Kirim ulasan'}</button>
 </form>}
 {status&&<p role="status">{status==='pending'?'Menunggu persetujuan admin.':status==='approved'?'Ulasan sudah tampil publik. Perubahan akan diperiksa kembali.':'Ulasan ditolak/disembunyikan. Kamu dapat memperbaikinya.'}</p>}{error&&<p className="form-error" role="alert">{error}</p>}</section>;
}

