import { readFile } from 'node:fs/promises';
const source = await readFile(new URL('./worker.js', import.meta.url), 'utf8');
export const worker = (await import(`data:text/javascript;base64,${Buffer.from(source).toString('base64')}`)).default;
export const owner = 'a'.repeat(72);
export const png = new Uint8Array([137,80,78,71,13,10,26,10,0]);

// Test double ONLY. Production uses Cloudflare's distributed native binding.
export class FakeRateBinding {
  constructor(maximum, clock) { this.maximum=maximum; this.clock=clock; this.windows=new Map(); this.keys=[]; }
  async limit({key}) {
    this.keys.push(key);
    const window=Math.floor(this.clock.now/60000);
    const current=this.windows.get(key);
    const count=current?.window===window ? current.count : 0;
    this.windows.set(key,{window,count:count+1});
    return {success:count<this.maximum};
  }
}
export function withRateLimits(env={},clock={now:0}) {
  return Object.assign(env, {
    UPLOAD_RATE_LIMITER:new FakeRateBinding(20,clock),
    UPLOAD_IP_RATE_LIMITER:new FakeRateBinding(60,clock),
    MODERATION_RATE_LIMITER:new FakeRateBinding(60,clock),
    DELETE_RATE_LIMITER:new FakeRateBinding(120,clock),
  });
}
export function request(path, {body, token=owner, ip='192.0.2.1', type='application/json', method=body===undefined?'GET':'POST', headers={}}={}) {
  const h={'Content-Type':type, 'X-Lumaunt-Owner':token,...headers};
  if(ip!==null) h['CF-Connecting-IP']=ip;
  return new Request('https://api.lumaunt.app'+path,{method,headers:h,body});
}
export class Bucket {
  objects=new Map(); writes=0; deletes=0; reads=0;
  async put(key,body,opts) { this.writes++;this.objects.set(key,{key,body,...opts}); }
  async head(key) { this.reads++; return this.objects.get(key)??null; }
  async delete(key) { this.deletes++;this.objects.delete(key); }
  async list({prefix,cursor,limit}) {
    const after=[...this.objects.values()].filter(x=>x.key.startsWith(prefix)&&(!cursor||x.key>cursor)).sort((a,b)=>a.key.localeCompare(b.key));
    const objects=after.slice(0,limit);
    return {objects,truncated:after.length>objects.length,cursor:objects.at(-1)?.key};
  }
}
