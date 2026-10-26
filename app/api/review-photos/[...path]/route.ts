import {createClient} from '@supabase/supabase-js';
const photoPath=/^[0-9a-f-]{36}\/[0-9a-f-]{36}\/[a-zA-Z0-9_-]+\.(webp|jpg|png)$/i;
export async function GET(_request:Request,{params}:{params:Promise<{path:string[]}>}){
 const path=(await params).path.join('/');if(!photoPath.test(path))return new Response('Not found',{status:404});
 const url=process.env.NEXT_PUBLIC_SUPABASE_URL,key=process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;if(!url||!key)return new Response('Unavailable',{status:503});
 const client=createClient(url,key,{auth:{persistSession:false,autoRefreshToken:false},global:{fetch:(input,init)=>fetch(input,{...init,signal:AbortSignal.timeout(10000)})}});
 const result=await client.storage.from('review-photos').download(path);if(result.error||!result.data)return new Response('Not found',{status:404,headers:{'Cache-Control':'no-store'}});
 return new Response(result.data,{headers:{'Content-Type':result.data.type||'image/webp','Cache-Control':'public, max-age=300, stale-while-revalidate=600','X-Content-Type-Options':'nosniff'}});
}
