'use client';
import {useEffect,useState} from 'react';
import Link from 'next/link';
import Image from 'next/image';
import {X} from 'lucide-react';
import {orderApi} from '@/lib/order-api';
import type {Review} from '@/lib/reviews';
type PendingReview=Review&{status:string;order_id:string|null;photos:{id:string;path:string;size_bytes:number;url:string|null}[]};
export default function AdminReviews(){
 const [rows,setRows]=useState<PendingReview[]>([]),[loading,setLoading]=useState(true),[busy,setBusy]=useState(''),[error,setError]=useState(''),[lightbox,setLightbox]=useState<string|null>(null);
 async function load(){try{setRows((await orderApi('/api/admin/reviews')).reviews);}catch(e){setError((e as Error).message);}finally{setLoading(false);}}
 useEffect(()=>{void load();},[]);
 async function act(id:string,action:'approved'|'hidden'|'delete'){if(action==='delete'&&!window.confirm('Hapus ulasan dan semua fotonya secara permanen?'))return;setBusy(id);setError('');try{await orderApi('/api/admin/reviews',{id,action});await load();}catch(e){setError((e as Error).message);}finally{setBusy('');}}
 return <main className="admin-shell"><nav className="chips"><Link href="/admin">Pembelian</Link><Link href="/admin/settings">Produk</Link><Link href="/admin/content">Konten</Link></nav><h1>Moderasi ulasan</h1><p className="muted">Ulasan pending ditampilkan di sini. Hanya ulasan disetujui yang muncul ke publik.</p>{loading&&<p role="status">Memuat…</p>}{error&&<p role="alert" className="form-error">{error}</p>}{!loading&&!rows.length&&<p>Belum ada ulasan menunggu persetujuan.</p>}
 {rows.map(r=><article className="panel review-item admin-review-card" key={r.id}><strong>{r.display_name} · {r.rating}/5</strong><p>{r.body}</p><small>{r.order_id?'Pesanan terverifikasi':'Pesanan tidak terhubung'} · {new Date(r.created_at).toLocaleDateString('id-ID')}</small>{!!r.photos.length&&<div className="review-public-photos">{r.photos.map(p=>p.url&&<button key={p.id} type="button" onClick={()=>setLightbox(p.url!)} aria-label="Lihat foto ulasan"><Image src={p.url} alt="Foto lampiran ulasan" width={92} height={92} loading="lazy" unoptimized/></button>)}</div>}<div className="chips"><button disabled={!!busy||!r.order_id} className="button primary" onClick={()=>void act(r.id,'approved')}>{busy===r.id?'Memproses…':'Setujui'}</button><button disabled={!!busy} className="button secondary" onClick={()=>void act(r.id,'hidden')}>Tolak</button><button disabled={!!busy} className="button secondary" onClick={()=>void act(r.id,'delete')}>Hapus ulasan & foto</button></div></article>)}
 {lightbox&&<div className="review-lightbox" role="dialog" aria-modal="true" aria-label="Foto ulasan" onClick={()=>setLightbox(null)}><button type="button" aria-label="Tutup foto"><X size={24}/></button><Image src={lightbox} alt="Foto ulasan diperbesar" width={1280} height={1280} unoptimized onClick={e=>e.stopPropagation()}/></div>}
 </main>;
}
