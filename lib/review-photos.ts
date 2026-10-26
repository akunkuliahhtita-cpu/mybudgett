export const REVIEW_PHOTO_MAX_BYTES=300_000;
export const REVIEW_PHOTO_MAX_ORIGINAL=5*1024*1024;
const accepted=new Set(['image/jpeg','image/png','image/webp']);

export async function compressReviewPhoto(file:File):Promise<Blob>{
 if(!accepted.has(file.type))throw new Error('Foto harus JPG, PNG, atau WebP.');
 if(file.size>REVIEW_PHOTO_MAX_ORIGINAL)throw new Error('Ukuran foto asli maksimal 5 MB.');
 let bitmap:ImageBitmap;
 try{bitmap=await createImageBitmap(file);}catch{throw new Error('File tidak dapat dibaca sebagai gambar.');}
 try{
  const scale=Math.min(1,1280/Math.max(bitmap.width,bitmap.height));
  const canvas=document.createElement('canvas');canvas.width=Math.max(1,Math.round(bitmap.width*scale));canvas.height=Math.max(1,Math.round(bitmap.height*scale));
  const context=canvas.getContext('2d');if(!context)throw new Error('Browser tidak dapat memproses foto.');context.drawImage(bitmap,0,0,canvas.width,canvas.height);
  for(const quality of [.86,.78,.68,.58,.48,.38,.3]){
   const blob=await new Promise<Blob|null>(resolve=>canvas.toBlob(resolve,'image/webp',quality));
   if(blob&&blob.size<REVIEW_PHOTO_MAX_BYTES)return blob;
  }
  throw new Error('Foto sulit dikompres di bawah 300 KB. Pilih foto lain.');
 }finally{bitmap.close();}
}

export function reviewPhotoUrl(path:string){return `/api/review-photos/${path.split('/').map(encodeURIComponent).join('/')}`;}


