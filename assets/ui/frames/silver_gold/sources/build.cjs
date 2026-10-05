// Packaging only: crop, resolution variants, nine-slice extraction and preview.
const sharp = require('sharp');
const fs = require('node:fs/promises');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const source = process.argv[2] || path.join(__dirname, 'generated.png');
const webp = {lossless:true, effort:6};
const rects = {
  corner_tl:[0,0,32,32], corner_tr:[160,0,32,32],
  corner_bl:[0,160,32,32], corner_br:[160,160,32,32],
  edge_top:[32,0,128,32], edge_bottom:[32,160,128,32],
  edge_left:[0,32,32,128], edge_right:[160,32,32,128]
};
async function compose(parts,w,h) {
  const out=[];
  for(const [name,box] of Object.entries(rects)) {
    let [x,y,pw,ph]=box;
    if(x===160)x=w-32;
    if(y===160)y=h-32;
    if(pw===128)pw=w-64;
    if(ph===128)ph=h-64;
    out.push({input:await sharp(parts[name]).resize(pw,ph,{fit:'fill'}).png().toBuffer(),left:x,top:y});
  }
  return sharp({create:{width:w,height:h,channels:4,background:'#00000000'}}).composite(out).png().toBuffer();
}
(async()=>{
  await fs.copyFile(source,path.join(__dirname,'generated.png')).catch(e=>{if(e.code!=='EINVAL')throw e});
  const parts={};
  const checks=[];
  for(const factor of [1,2,4]) {
    const size=192*factor, suffix=factor===1?'':`@${factor}x`;
    const png=await sharp(source).extract({left:52,top:52,width:1152,height:1152}).resize(size,size).png().toBuffer();
    const file=path.join(root,`frame${suffix}.webp`);
    await sharp(png).webp(webp).toFile(file);
    const before=await sharp(png).raw().toBuffer();
    const after=await sharp(file).raw().toBuffer();
    // Lossless visible RGBA: invisible RGB is allowed to be canonicalized by WebP.
    let mismatches=0;
    for(let i=0;i<before.length;i+=4) {
      if(before[i+3]!==after[i+3] || (before[i+3]>0 && !before.subarray(i,i+3).equals(after.subarray(i,i+3))))mismatches++;
    }
    if(mismatches)throw Error('Lossless check failed');
    checks.push({file:path.basename(file),size:[size,size],visible_pixel_mismatches:mismatches,center_alpha:after[((size/2)*size+size/2)*4+3]});
    for(const [name,[left,top,width,height]] of Object.entries(rects)) {
      const piece=await sharp(png).extract({left:left*factor,top:top*factor,width:width*factor,height:height*factor}).webp(webp).toBuffer();
      await fs.writeFile(path.join(root,'parts',`${name}${suffix}.webp`),piece);
      if(factor===1)parts[name]=piece;
    }
  }
  const examples=[{w:128,h:144,x:32,y:80},{w:224,h:224,x:192,y:80},{w:400,h:112,x:448,y:80},{w:580,h:288,x:32,y:350},{w:204,h:288,x:644,y:350}];
  const overlays=[];
  for(const e of examples)overlays.push({input:await compose(parts,e.w,e.h),left:e.x,top:e.y});
  const svg=Buffer.from(`<svg width="880" height="680"><style>text{font-family:Arial;fill:#dce8f5;font-size:16px}</style><text x="32" y="35" font-size="23">SILBER / GOLD — ein Akzent pro Ecke</text><text x="32" y="60">Gleiche Ecken und Rahmenstärke in allen Größen · transparente Mitte</text>${examples.map(e=>`<text x="${e.x}" y="${e.y+e.h+23}">${e.w} × ${e.h}</text>`).join('')}</svg>`);
  overlays.push({input:svg,left:0,top:0});
  await sharp({create:{width:880,height:680,channels:4,background:'#102236'}}).composite(overlays).webp(webp).toFile(path.join(root,'preview','sizes.webp'));
  await fs.writeFile(path.join(root,'preview','checks.json'),JSON.stringify({checks,preview_sizes:examples.map(({w,h})=>[w,h]),gold_accents:4},null,2)+'\n');
  console.log(JSON.stringify(checks));
})();
