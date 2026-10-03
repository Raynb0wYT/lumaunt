import test from 'node:test';
import assert from 'node:assert/strict';
import { worker as originalWorker, withRateLimits, Bucket, owner, png } from './test-fixtures.mjs';
const other = 'b'.repeat(72);
const worker = {
  ...originalWorker,
  fetch(request, env) {
    request.headers.set('CF-Connecting-IP', '192.0.2.1');
    if (!env.UPLOAD_RATE_LIMITER) withRateLimits(env);
    return originalWorker.fetch(request, env);
  }
};
function upload(env, {token=owner, days=30, body=png, type='image/png'}={}) {
  return worker.fetch(new Request('https://api.lumaunt.app/v2/images/upload', {
    method:'POST', headers:{'Content-Type':type,'X-Lumaunt-Owner':token,'X-Lumaunt-Retention-Days':String(days)}, body
  }),env);
}
function remove(env,key,token=owner) {
  return worker.fetch(new Request('https://api.lumaunt.app/v2/images/delete', {
    method:'POST', headers:{'Content-Type':'application/json','X-Lumaunt-Owner':token}, body:JSON.stringify({key})
  }),env);
}
test('upload stores a hashed owner, public URL and fixed expiry', async()=>{
  for (const days of [7,30,90]) {
    const env={IMAGES:new Bucket()}; const before=Date.now();
    const response=await upload(env,{days}); assert.equal(response.status,201);
    const image=await response.json(); const record=await env.IMAGES.head(image.key);
    assert.match(image.url,/^https:\/\/images\.lumaunt\.app\/managed-images\//);
    assert.ok(image.expiresAt >= before + days*86400000);
    assert.ok(image.expiresAt <= Date.now() + days*86400000);
    assert.equal(record.customMetadata.owner.length,64); assert.notEqual(record.customMetadata.owner,owner);
    assert.equal(record.httpMetadata.cacheControl,'no-store');
  }
});
test('rejects missing ownership, invalid retention and fake image bytes', async()=>{
 const env={IMAGES:new Bucket()};
 assert.equal((await upload(env,{token:''})).status,401);
 assert.equal((await upload(env,{days:0})).status,400);
 assert.equal((await upload(env,{body:new Uint8Array([1,2,3])})).status,415);
 assert.equal(env.IMAGES.objects.size,0);
});
test('rejects oversized bodies without Content-Length',async()=>{
 const env={IMAGES:new Bucket()};
 assert.equal((await upload(env,{body:new Uint8Array(5*1024*1024+1)})).status,413);
 assert.equal(env.IMAGES.objects.size,0);
});
test('only owner can delete; repeat deletion is safe; legacy paths rejected', async()=>{
 const env={IMAGES:new Bucket()}; const image=await (await upload(env)).json();
 assert.equal((await remove(env,image.key,other)).status,403);
 assert.ok(await env.IMAGES.head(image.key));
 assert.equal((await remove(env,'images/legacy.png')).status,400);
 assert.equal((await remove(env,image.key)).status,200);
 assert.equal(await env.IMAGES.head(image.key),null);
 assert.equal((await remove(env,image.key)).status,200);
});
test('daily cleanup paginates and only deletes expired managed images', async()=>{
 const env={IMAGES:new Bucket()};
 for(let i=0;i<1005;i++) await env.IMAGES.put(`managed-images/${String(i).padStart(5,'0')}.png`,png,{customMetadata:{privacyVersion:'1',owner:'hash',expiresAt:String(Date.now()-100)}});
 await env.IMAGES.put('images/legacy.png',png,{customMetadata:{expiresAt:'1'}});
 await env.IMAGES.put('managed-images/keep.png',png,{customMetadata:{privacyVersion:'1',owner:'hash',expiresAt:String(Date.now()+100000)}});
 await env.IMAGES.put('managed-images/unknown.png',png,{customMetadata:{}});
 let pending;
 await worker.scheduled({},env,{waitUntil(p){pending=p;}}); await pending;
 assert.deepEqual([...env.IMAGES.objects.keys()].sort(),['images/legacy.png','managed-images/keep.png','managed-images/unknown.png']);
});
test('existing health and moderation routes remain present',async()=>{
 assert.equal((await worker.fetch(new Request('https://api.lumaunt.app/'),{})).status,200);
 assert.equal((await worker.fetch(new Request('https://api.lumaunt.app/v1/moderate/text',{method:'POST'}),{})).status,500);
 assert.equal((await worker.fetch(new Request('https://api.lumaunt.app/v2/images/capabilities'),{})).status,200);
});
