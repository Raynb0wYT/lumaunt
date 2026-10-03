import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { worker, withRateLimits, request, Bucket, owner, png } from './test-fixtures.mjs';
const managed=(env,opts={})=>worker.fetch(request('/v2/images/upload',{body:png,type:'image/png',headers:{'X-Lumaunt-Retention-Days':'30'},...opts}),env);
const moderate=(env,path='/v1/moderate/text',opts={})=>worker.fetch(request(path,{body:JSON.stringify({text:'Playing a game',suspectedCategory:'threats'}),...opts}),env);

function installOpenAIStub() {
  const previous=globalThis.fetch;
  let calls=0;
  globalThis.fetch=async(url,options)=>{
    assert.equal(url,'https://api.openai.com/v1/moderations'); calls++;
    assert.equal(JSON.parse(options.body).input,'Playing a game');
    return Response.json({results:[{flagged:false,categories:{},category_scores:{}}]});
  };
  return {get calls(){return calls},restore(){globalThis.fetch=previous}};
}

test('20 uploads allowed; next is 429 before body read or R2 write; resets',async()=>{
 const clock={now:0},env=withRateLimits({IMAGES:new Bucket()},clock);
 for(let i=0;i<20;i++) assert.equal((await managed(env)).status,201);
 const req=request('/v2/images/upload',{body:png,type:'image/png',headers:{'X-Lumaunt-Retention-Days':'30'}});
 const response=await worker.fetch(req,env);
 assert.equal(response.status,429); assert.equal(req.bodyUsed,false); assert.equal(env.IMAGES.writes,20);
 assert.equal(response.headers.get('Retry-After'),null);
 assert.deepEqual(await response.json(),{error:'Too many requests. Please try again shortly.'});
 clock.now=60000; assert.equal((await managed(env)).status,201);
});
test('rotating owner tokens cannot bypass aggregate IP upload budget',async()=>{
 const env=withRateLimits({IMAGES:new Bucket()});
 for(let i=0;i<60;i++) assert.equal((await managed(env,{token:String(i).padStart(72,'x')})).status,201);
 assert.equal((await managed(env,{token:'z'.repeat(72)})).status,429);
 assert.equal(env.IMAGES.writes,60);
});
test('raw owner and IP are never passed to native rate bindings',async()=>{
 const env=withRateLimits({IMAGES:new Bucket()}); await managed(env);
 for(const binding of [env.UPLOAD_RATE_LIMITER,env.UPLOAD_IP_RATE_LIMITER]) {
  assert.ok(binding.keys.length);
  assert.ok(binding.keys.every(k=>!k.includes(owner)&&!k.includes('192.0.2.1')));
  assert.ok(binding.keys.every(k=>/^(owner|ip):[0-9a-f]{64}$/.test(k)));
 }
});
test('60 normal OpenAI calls succeed; 429 prevents outbound calls and body read; resets',async()=>{
 const stub=installOpenAIStub(),clock={now:0},env=withRateLimits({OPENAI_API_KEY:'test-only'},clock);
 try {
  for(let i=0;i<60;i++) { const res=await moderate(env);assert.equal(res.status,200);assert.equal((await res.json()).allowed,true); }
  const req=request('/v1/moderate/text',{body:'{}'});assert.equal((await worker.fetch(req,env)).status,429);
  assert.equal(req.bodyUsed,false);assert.equal(stub.calls,60);
  clock.now=60000;assert.equal((await moderate(env)).status,200);assert.equal(stub.calls,61);
 } finally { stub.restore(); }
});
test('60 contextual calls succeed; 429 prevents Workers AI and body read; resets',async()=>{
 let calls=0; const clock={now:0},env=withRateLimits({AI:{async run(){calls++;return {response:{classification:'contextual'}}}}},clock);
 for(let i=0;i<60;i++) {const res=await moderate(env,'/v1/moderate/context');assert.equal(res.status,200);assert.equal((await res.json()).confirmed,false);}
 const req=request('/v1/moderate/context',{body:'{}'});assert.equal((await worker.fetch(req,env)).status,429);
 assert.equal(req.bodyUsed,false);assert.equal(calls,60);
 clock.now=60000;assert.equal((await moderate(env,'/v1/moderate/context')).status,200);assert.equal(calls,61);
});
test('both moderation routes share the 60-request IP budget; owner rotation is ignored',async()=>{
 const stub=installOpenAIStub();let aiCalls=0;
 const env=withRateLimits({OPENAI_API_KEY:'test-only',AI:{async run(){aiCalls++;return {response:{classification:'contextual'}}}}});
 try {
  for(let i=0;i<30;i++) {assert.equal((await moderate(env)).status,200);assert.equal((await moderate(env,'/v1/moderate/context')).status,200);}
  assert.equal((await moderate(env,'/v1/moderate/text',{token:'c'.repeat(72)})).status,429);
  assert.equal(stub.calls,30);assert.equal(aiCalls,30);
 } finally {stub.restore();}
});
test('delete-all can issue 120 deletions; limit protects R2 metadata reads',async()=>{
 const env=withRateLimits({IMAGES:new Bucket()});
 const image=await (await managed(env)).json();
 const del=()=>worker.fetch(request('/v2/images/delete',{body:JSON.stringify({key:image.key})}),env);
 for(let i=0;i<120;i++) assert.equal((await del()).status,200);
 assert.equal((await del()).status,429);assert.equal(env.IMAGES.reads,120);assert.equal(env.IMAGES.deletes,1);
});
test('legacy route remains compatible but is limited and shares aggregate IP upload budget',async()=>{
 const env=withRateLimits({IMAGES:new Bucket()});
 const legacy=()=>worker.fetch(request('/images/upload',{body:png,type:'image/png'}),env);
 for(let i=0;i<20;i++) {const res=await legacy();assert.equal(res.status,201);assert.match((await res.json()).key,/^images\//);}
 assert.equal((await legacy()).status,429);assert.equal(env.IMAGES.writes,20);
});
test('legacy upload and JSON bodies enforce bounded reads without truthful Content-Length',async()=>{
 const env=withRateLimits({IMAGES:new Bucket(),OPENAI_API_KEY:'test-only'});
 assert.equal((await worker.fetch(request('/images/upload',{body:new Uint8Array(5*1024*1024+1),type:'image/png',headers:{'Content-Length':'1'}}),env)).status,413);
 assert.equal((await moderate(env,'/v1/moderate/text',{body:JSON.stringify({text:'x'.repeat(20000)}),headers:{'Content-Length':'1'}})).status,413);
 assert.equal(env.IMAGES.writes,0);
});
test('moderation text/category/content-type and retention validation remain enforced',async()=>{
 const env=withRateLimits({OPENAI_API_KEY:'test-only',AI:{async run(){throw new Error('must not call')}},IMAGES:new Bucket()});
 assert.equal((await moderate(env,'/v1/moderate/text',{body:JSON.stringify({text:'x'.repeat(2001)})})).status,413);
 assert.equal((await moderate(env,'/v1/moderate/context',{body:JSON.stringify({text:'Hello',suspectedCategory:'unknown'})})).status,400);
 assert.equal((await moderate(env,'/v1/moderate/text',{type:'text/plain'})).status,415);
 assert.equal((await managed(env,{headers:{'X-Lumaunt-Retention-Days':'365'}})).status,400);
});
test('missing/broken bindings fail closed and expose no internals; health remains available',async()=>{
 const env={IMAGES:new Bucket()};assert.equal((await managed(env)).status,503);assert.equal(env.IMAGES.writes,0);
 const broken=withRateLimits({IMAGES:new Bucket()});broken.UPLOAD_IP_RATE_LIMITER={async limit(){throw new Error('secret-details')}};
 const response=await managed(broken);assert.equal(response.status,503);assert.ok(!(await response.text()).includes('secret-details'));
 assert.equal((await worker.fetch(request('/'),{})).status,200);
 assert.equal((await worker.fetch(request('/v2/images/capabilities'),{})).status,200);
});
test('missing connecting IP cannot be replaced by spoofable forwarded headers',async()=>{
 const env=withRateLimits({IMAGES:new Bucket()});
 assert.equal((await managed(env,{ip:null,headers:{'X-Forwarded-For':'192.0.2.1','X-Real-IP':'192.0.2.1','X-Lumaunt-Retention-Days':'30'}})).status,503);
 assert.equal(env.IMAGES.writes,0);
});
test('independent clients have independent counters; GET, wrong methods/routes and CORS unaffected',async()=>{
 const env=withRateLimits({IMAGES:new Bucket()});
 for(let i=0;i<20;i++) await managed(env);
 assert.equal((await managed(env,{token:'c'.repeat(72),ip:'192.0.2.2'})).status,201);
 const before=env.UPLOAD_RATE_LIMITER.keys.length;
 for(const path of ['/','/v2/images/capabilities']) for(let i=0;i<100;i++) assert.equal((await worker.fetch(request(path),env)).status,200);
 for(const path of ['/v2/images/upload','/unknown']) {
  const response=await worker.fetch(request(path,{method:'OPTIONS'}),env);assert.equal(response.status,404);assert.equal(response.headers.get('Access-Control-Allow-Origin'),null);
 }
 assert.equal(env.UPLOAD_RATE_LIMITER.keys.length,before);
});
test('configured native bindings match the policy and preserve storage, AI and daily cleanup',async()=>{
 const cfg=JSON.parse(await readFile(new URL('./wrangler.jsonc',import.meta.url),'utf8'));
 assert.deepEqual(cfg.ratelimits.map(x=>[x.name,x.simple.limit,x.simple.period]),[
  ['UPLOAD_RATE_LIMITER',20,60],['UPLOAD_IP_RATE_LIMITER',60,60],['MODERATION_RATE_LIMITER',60,60],['DELETE_RATE_LIMITER',120,60]]);
 assert.equal(new Set(cfg.ratelimits.map(x=>x.namespace_id)).size,4);
 assert.equal(cfg.r2_buckets[0].binding,'IMAGES');assert.equal(cfg.ai.binding,'AI');assert.deepEqual(cfg.triggers.crons,['0 4 * * *']);
});
