import { createRequire } from 'node:module';
import { readFile } from 'node:fs/promises';
import assert from 'node:assert/strict';
const require=createRequire(import.meta.url);
const {Miniflare,convertV4MiniflareOptions}=createRequire(require.resolve('wrangler/package.json'))('miniflare');
const dir = new URL('./', import.meta.url);
let source=await readFile(new URL('worker.js',dir),'utf8');
// Provider mocks only in this unpublished test copy. Rate bindings/R2 run natively.
source='const fetch = async () => Response.json({results:[{flagged:false,categories:{},category_scores:{}}]});\n'+source;
source=source.replace('async fetch(request, env) {','async fetch(request, env) { env.OPENAI_API_KEY="test-only"; env.AI={run:async()=>({response:{classification:"contextual"}})};');
const cfg=JSON.parse(await readFile(new URL('wrangler.jsonc',dir),'utf8'));
const mf=new Miniflare(convertV4MiniflareOptions({modules:true,script:source,compatibilityDate:cfg.compatibility_date,r2Buckets:['IMAGES'],ratelimits:Object.fromEntries(cfg.ratelimits.map(({name,...opts})=>[name,opts]))}));
const owner='a'.repeat(72);
const png = Uint8Array.from(Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=', 'base64'));
const call=(path,body,ip='192.0.2.1',type='application/json')=>mf.dispatchFetch('https://api.lumaunt.app'+path,{method:body?'POST':'GET',headers:{'Content-Type':type,'X-Lumaunt-Owner':owner,'X-Lumaunt-Retention-Days':'7','CF-Connecting-IP':ip},body});
try {
 assert.equal((await call('/')).status,200);
 const image=await (await call('/v2/images/upload',png,'192.0.2.1','image/png')).json();
 assert.ok(image.key?.startsWith('managed-images/'));
 assert.equal((await call('/v2/images/delete',JSON.stringify({key:image.key}))).status,200);
 let blocked=false;
 for(let i=0;i<50;i++) {const r=await call('/v2/images/upload',png,'192.0.2.1','image/png');if(r.status===429){blocked=true;break;}assert.equal(r.status,201);}
 assert.ok(blocked); console.log('Native bindings: image upload/delete and 429 passed');
 const body=JSON.stringify({text:'Playing a game',suspectedCategory:'threats'});
 for(const [route,ip] of [['/v1/moderate/text','192.0.2.2'],['/v1/moderate/context','192.0.2.3']]) {
  let limited=false;
  for(let i=0;i<100;i++) {const r=await call(route,body,ip);if(r.status===429){limited=true;break;}assert.equal(r.status,200);}
  assert.ok(limited);console.log('Native bindings: '+route+' normal responses and 429 passed');
 }
 assert.equal((await call('/v2/images/capabilities')).status,200);
 console.log('Native bindings: health/capabilities unaffected');
} finally {await mf.dispose();}
