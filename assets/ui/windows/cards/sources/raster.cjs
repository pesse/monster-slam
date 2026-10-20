// Shared deterministic raster helpers. Requires sharp >= 0.33 (npm install sharp).
const fs = require('node:fs');
let sharp;
try { sharp = require('sharp'); } catch {
  sharp = require(process.env.MONSTER_SHARP || 'C:/Users/SamuelNitsche/AppData/Local/OpenAI/Codex/runtimes/cua_node/a5a02988362ca169/bin/node_modules/sharp');
}
const clamp = (v,a=0,b=255) => Math.max(a,Math.min(b,v));
function raster(w,h,fill=[0,0,0,0]) { const data=Buffer.alloc(w*h*4); for(let i=0;i<w*h;i++)data.set(fill,i*4); return {data,w,h}; }
const get=(im,x,y)=>Array.from(im.data.subarray((y*im.w+x)*4,(y*im.w+x)*4+4));
const set=(im,x,y,p)=>im.data.set(p.map(v=>Math.round(clamp(v))),(y*im.w+x)*4);
const mix=(a,b,t)=>a.map((v,i)=>v*(1-t)+b[i]*t);
async function load(file,w,h) { let s=sharp(file).ensureAlpha(); if(w)s=s.resize(w,h,{fit:'fill',kernel:'lanczos3'}); const {data,info}=await s.raw().toBuffer({resolveWithObject:true}); return {data,w:info.width,h:info.height}; }
async function png(im,file) { await sharp(im.data,{raw:{width:im.w,height:im.h,channels:4}}).png().toFile(file); }
function crop(im,x,y,w,h) {let o=raster(w,h); for(let j=0;j<h;j++)for(let i=0;i<w;i++)set(o,i,j,get(im,x+i,y+j));return o;}
function paste(dst,src,x,y) {for(let j=0;j<src.h;j++)for(let i=0;i<src.w;i++){if(x+i<0||x+i>=dst.w||y+j<0||y+j>=dst.h)continue;let p=get(src,i,j),q=get(dst,x+i,y+j),a=p[3]/255,b=q[3]/255,A=a+b*(1-a);set(dst,x+i,y+j,A?[(p[0]*a+q[0]*b*(1-a))/A,(p[1]*a+q[1]*b*(1-a))/A,(p[2]*a+q[2]*b*(1-a))/A,A*255]:[0,0,0,0]);}return dst;}
function periodic(im,horizontal=true,vertical=true,band=12) {
  // Symmetric edge blend: no linear illumination ramp or vignette is added.
  let out={...im,data:Buffer.from(im.data)};
  if(horizontal)for(let y=0;y<im.h;y++)for(let i=0;i<band;i++){
    let t=(1+Math.cos(Math.PI*i/band))/2, a=get(im,i,y),b=get(im,im.w-1-i,y),m=mix(a,b,.5);
    set(out,i,y,mix(a,m,t));set(out,im.w-1-i,y,mix(b,m,t));
  }
  if(vertical){let before={...out,data:Buffer.from(out.data)};for(let x=0;x<im.w;x++)for(let i=0;i<band;i++){
    let t=(1+Math.cos(Math.PI*i/band))/2,a=get(before,x,i),b=get(before,x,im.h-1-i),m=mix(a,b,.5);
    set(out,x,i,mix(a,m,t));set(out,x,im.h-1-i,mix(b,m,t));
  }}return out;
}
function nine(im,w,h,m=[32,32,32,32]) {
  const [l,r,t,b]=m,cw=im.w-l-r,ch=im.h-t-b,o=raster(w,h);
  for(let y=0;y<h;y++)for(let x=0;x<w;x++){
    const sx=x<l?x:x>=w-r?im.w-(w-x):l+(x-l)%cw;
    const sy=y<t?y:y>=h-b?im.h-(h-y):t+(y-t)%ch;
    set(o,x,y,get(im,sx,sy));
  }return o;
}
function seam(im,rect,axis){let [x,y,w,h]=rect,max=0,sum=0,n=0;for(let j=0;j<(axis==='x'?h:w);j++){let a=get(im,x+(axis==='x'?0:j),y+(axis==='x'?j:0)),b=get(im,x+(axis==='x'?w-1:j),y+(axis==='x'?j:h-1));for(let c=0;c<4;c++){let d=Math.abs(a[c]-b[c]);max=Math.max(max,d);sum+=d;n++;}}return {max_channel_delta:max,mean_channel_delta:sum/n};}
async function exportAsset(im,root,name){await png(im,root+'/sources/'+name+'-raw.png');const file=root+'/'+name+'.webp';await sharp(im.data,{raw:{width:im.w,height:im.h,channels:4}}).webp({lossless:true,effort:6,alphaQuality:100}).toFile(file);const decoded=await load(file);let visibleEqual=true,max=0,minA=255,maxA=0;for(let i=0;i<im.data.length;i+=4){minA=Math.min(minA,decoded.data[i+3]);maxA=Math.max(maxA,decoded.data[i+3]);for(let c=0;c<4;c++){if(c<3&&!im.data[i+3])continue;let d=Math.abs(im.data[i+c]-decoded.data[i+c]);max=Math.max(max,d);if(d)visibleEqual=false;}}const bytes=fs.readFileSync(file);const checks={width:decoded.w,height:decoded.h,channels:4,alpha_min:minA,alpha_max:maxA,lossless_VP8L:bytes.includes(Buffer.from('VP8L')),rgba_roundtrip_visible_equal:visibleEqual,max_roundtrip_delta:max};if(!visibleEqual||!checks.lossless_VP8L)throw Error('WebP contract: '+name);return {im:decoded,checks};}
async function label(im,text,x,y,size=16,color='#dce6f6') {const escape=s=>s.replaceAll('&','&amp;').replaceAll('<','&lt;'); const svg=Buffer.from(`<svg width="${im.w}" height="${im.h}" xmlns="http://www.w3.org/2000/svg"><text x="${x}" y="${y}" font-family="Arial, sans-serif" font-size="${size}" font-weight="600" fill="${color}">${escape(text)}</text></svg>`);const data=await sharp(im.data,{raw:{width:im.w,height:im.h,channels:4}}).composite([{input:svg}]).raw().toBuffer();im.data=data;}
async function zoom(im,factor){return {data:await sharp(im.data,{raw:{width:im.w,height:im.h,channels:4}}).resize(im.w*factor,im.h*factor,{kernel:'nearest'}).raw().toBuffer(),w:im.w*factor,h:im.h*factor};}
module.exports={fs,sharp,clamp,raster,get,set,mix,load,png,crop,paste,periodic,nine,seam,exportAsset,label,zoom};
