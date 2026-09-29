// Preserve exact original geometry; remove navy matte from gold contour pixels.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const sharp=require(process.env.SHARP_MODULE||'sharp');
const root=path.resolve(__dirname,'..'),P=n=>path.join(root,n);
async function clean(file){
 const {data:d,info}=await sharp(P(file)).ensureAlpha().raw().toBuffer({resolveWithObject:true});
 for(let p=0;p<d.length;p+=4){
  const r=d[p],g=d[p+1],b=d[p+2];
  if(r-b<12||g-b<8||r<g*.94){d.fill(0,p,p+4);continue;}
  // Estimate gold coverage against the old blue matte, then unpremultiply it.
  const coverage=Math.min(1,(r-b+24)/226),a=Math.round(d[p+3]*coverage);
  for(let c=0;c<3;c++)d[p+c]=Math.max(0,Math.min(255,Math.round((d[p+c]-(1-coverage)*[10,20,34][c])/coverage)));
  d[p+3]=a;
 }
 return {d,info};
}
async function run(){
 const names=['frame','pointer_up','pointer_right','pointer_down','pointer_left'],M=JSON.parse(fs.readFileSync(P('manifest.json'),'utf8')),checks=[];
 for(const n of names){
  const {d,info}=await clean('sources/tooltip-before-alpha/'+n+'.webp');
  if(n==='frame')for(let y=24;y<232;y++)for(let x=24;x<232;x++)if(d[(y*256+x)*4+3])throw Error('Nontransparent interior');
  const file=P(n+'.webp');fs.writeFileSync(file,await sharp(d,{raw:{width:info.width,height:info.height,channels:4}}).webp({lossless:true,effort:6}).toBuffer());
  const {data:decoded}=await sharp(file).ensureAlpha().raw().toBuffer({resolveWithObject:true});
  let dark=0,visible=0;for(let p=0;p<decoded.length;p+=4)if(decoded[p+3]){visible++;if(decoded[p]<decoded[p+2]||decoded[p]<90)dark++;}
  if(dark)throw Error('Dark matte remains');
  M.assets[n].sha256=crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
  M.assets[n].notes=n==='frame'?'Gold contour only; interior/exterior alpha=0. Nine-slice 24px unchanged.':'Gold contour only; transparent triangle interior and exterior; original dimensions unchanged.';
  checks.push({file:n+'.webp',width:info.width,height:info.height,visible_pixels:visible,dark_matte_pixels:dark,lossless:fs.readFileSync(file).includes(Buffer.from('VP8L'))});
 }
 fs.writeFileSync(P('manifest.json'),JSON.stringify(M,null,2)+'\n');
 const cells=[];for(let i=0;i<3;i++){
  const bg=['#ffffff','#f1e7d3','#91c6d6'][i];
  const layers=[{input:await sharp(P('frame.webp')).png().toBuffer(),left:16,top:16}];
  for(let j=1;j<names.length;j++)layers.push({input:await sharp(P(names[j]+'.webp')).png().toBuffer(),left:16+(j-1)*68,top:288});
  cells.push({input:await sharp({create:{width:288,height:364,channels:4,background:bg}}).composite(layers).png().toBuffer(),left:i*288,top:0});
 }
 await sharp({create:{width:864,height:364,channels:4,background:'#fff'}}).composite(cells).png().toFile(P('preview/tooltip-transparency.png'));
 fs.writeFileSync(P('preview/tooltip-alpha-check.json'),JSON.stringify({frame_center_alpha:0,checks},null,2)+'\n');console.log(checks);
}
if(require.main===module)run().catch(e=>{console.error(e);process.exitCode=1;});
module.exports={clean};
