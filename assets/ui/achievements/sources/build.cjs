// Rebuild only files inside ui/achievements. Requires Sharp (ACHIEVEMENTS_SHARP).
const fs = require('fs');
const path = require('path');
const sharp = require(process.env.ACHIEVEMENTS_SHARP || 'C:/Users/SamuelNitsche/AppData/Local/OpenAI/Codex/runtimes/cua_node/2fbcd108736f9c20/bin/node_modules/sharp');
const root = path.resolve(__dirname, '..');
const spec = JSON.parse(fs.readFileSync(path.join(__dirname, 'prompts.json'), 'utf8'));
const order = ['words_50','words_100','words_500','words_1000','mastered_first','mastered_100','unit_tier_4','book_tier_2','boss_first','boss_gold','streak_7','streak_30','level_5','level_10','level_20','chests_10','skill_first','skill_branch','badges_all','wave_last_hp','run_untouched','boss_flawless','revenge_3','hidden'];
// Shared 10% corner radius, analytically supersampled for smooth alpha edges.
function coverage(x,y) {
  let hit=0;
  for(let sy=0;sy<8;sy++) for(let sx=0;sx<8;sx++) {
    const px=x+(sx+.5)/8, py=y+(sy+.5)/8, r=25.6;
    const dx=px-Math.max(r,Math.min(256-r,px));
    const dy=py-Math.max(r,Math.min(256-r,py));
    if(dx*dx+dy*dy<=r*r) hit++;
  }
  return Math.round(255*hit/64);
}
function chunks(bytes) {
  const out=[];
  for(let p=12;p+8<=bytes.length;) {const id=bytes.toString('ascii',p,p+4),n=bytes.readUInt32LE(p+4);out.push(id);p+=8+n+(n%2);}
  return out;
}
async function main() {
  const report=[], images=new Map();
  for(const atlas of spec.atlases) {
    const file=path.join(__dirname,atlas.file),meta=await sharp(file).metadata();
    for(let i=0;i<atlas.cells.length;i++) {
      const {name}=atlas.cells[i];
      if(spec.atlases.slice(spec.atlases.indexOf(atlas)+1).some(a=>a.cells.some(c=>c.name===name))) continue;
      const x0=Math.round((i%3)*meta.width/3),x1=Math.round(((i%3)+1)*meta.width/3);
      const rows=atlas.rows||2;
      const y0=Math.round(Math.floor(i/3)*meta.height/rows),y1=Math.round((Math.floor(i/3)+1)*meta.height/rows);
      const source=name==='unit_tier_4'?path.join(__dirname,'anchor_unit_tier_4.png'):file;
      let pipeline=sharp(source);
      if(name!=='unit_tier_4') pipeline=pipeline.extract({left:x0,top:y0,width:x1-x0,height:y1-y0});
      const data=await pipeline.resize(256,256,{fit:'fill',kernel:'lanczos3'}).ensureAlpha().raw().toBuffer();
      let transparent=0,opaque=0,partial=0;
      for(let y=0;y<256;y++) for(let x=0;x<256;x++) {
        const a=coverage(x,y),p=(y*256+x)*4;
        data[p+3]=a;
        if(a===0) {data[p]=data[p+1]=data[p+2]=0;transparent++;}
        else if(a===255) opaque++; else partial++;
      }
      const output=path.join(root,'icons',name+'.webp');
      await sharp(data,{raw:{width:256,height:256,channels:4}}).webp({lossless:true,effort:6,alphaQuality:100}).toFile(output);
      const om=await sharp(output).metadata(),dec=await sharp(output).ensureAlpha().raw().toBuffer(),ch=chunks(fs.readFileSync(output));
      if(om.width!==256 || om.height!==256 || !om.hasAlpha || !ch.includes('VP8L') || ch.includes('VP8 ')) throw Error(name+': format validation failed');
      // VP8L may replace invisible RGB under alpha=0; all visible RGB and all alpha must be exact.
      for(let p=0;p<data.length;p+=4) {
        if(dec[p+3]!==data[p+3] || (data[p+3]>0 && (dec[p]!==data[p] || dec[p+1]!==data[p+1] || dec[p+2]!==data[p+2]))) throw Error(name+': visible lossless pixel round trip failed');
      }
      for(let y=0;y<256;y++) for(let x=0;x<256;x++) if(dec[(y*256+x)*4+3]!==coverage(x,y)) throw Error(name+': alpha geometry failed');
      report.push({name,width:om.width,height:om.height,channels:om.channels,hasAlpha:om.hasAlpha,encoding:'VP8L',losslessVisiblePixelRoundTrip:true,exactAlphaRoundTrip:true,transparentPixels:transparent,opaquePixels:opaque,antialiasedEdgePixels:partial,cornerRadius:25.6,opaqueInterior:true,source:path.basename(source),cell:name==='unit_tier_4'?null:[x0,y0,x1-x0,y1-y0]});
      images.set(name,await sharp(output).png().toBuffer());
    }
  }
  // Six columns, labels below icons; every icon remains at native export size.
  const cols=6,cw=284,ch=300,width=cols*cw,height=4*ch;
  const layers=[],grayLayers=[];
  for(const [i,name] of order.entries()) {
    const left=(i%cols)*cw+14,top=Math.floor(i/cols)*ch+8;
    layers.push({input:images.get(name),left,top});
    grayLayers.push({input:await sharp(images.get(name)).grayscale().modulate({brightness:.55}).png().toBuffer(),left,top});
    const svg=Buffer.from(`<svg width="284" height="32"><text x="142" y="22" text-anchor="middle" fill="#d8deeb" font-family="Arial, sans-serif" font-size="17">${name}</text></svg>`);
    layers.push({input:svg,left:left-14,top:top+260});
    grayLayers.push({input:await sharp(svg).grayscale().png().toBuffer(),left:left-14,top:top+260});
  }
  await sharp({create:{width,height,channels:4,background:'#1b2233'}}).composite(layers).png().toFile(path.join(root,'preview','all.png'));
  await sharp({create:{width,height,channels:4,background:'#1b2233'}}).composite(grayLayers).png().toFile(path.join(root,'preview','all_gray.png'));
  const small=[];
  for(const [i,name] of order.entries()) {
    const x=i%6*216,y=Math.floor(i/6)*110+28;
    small.push({input:await sharp(images.get(name)).resize(64,64).png().toBuffer(),left:x+4,top:y});
    small.push({input:await sharp(images.get(name)).resize(56,56).png().toBuffer(),left:x+78,top:y+4});
    small.push({input:await sharp(images.get(name)).resize(56,56).grayscale().modulate({brightness:.55}).png().toBuffer(),left:x+148,top:y+4});
    small.push({input:Buffer.from(`<svg width="216" height="24"><text x="108" y="18" text-anchor="middle" fill="#d8deeb" font-family="Arial" font-size="14">${name}</text></svg>`),left:x,top:y+68});
  }
  small.push({input:Buffer.from('<svg width="1296" height="24"><text x="648" y="18" text-anchor="middle" fill="#d8deeb" font-family="Arial" font-size="15">Je Motiv: 64 px Farbe · 56 px Farbe · 56 px gesperrt</text></svg>'),left:0,top:0});
  await sharp({create:{width:1296,height:468,channels:4,background:'#1b2233'}}).composite(small).png().toFile(path.join(root,'preview','size_check.png'));
  for(const folder of ['sources','preview']) fs.writeFileSync(path.join(root,folder,'.gdignore'),'');
  if(report.length!==24) throw Error('Expected exactly 24 icons');
  fs.writeFileSync(path.join(__dirname,'validation.json'),JSON.stringify({date:'2026-10-26',count:report.length,files:report},null,2)+'\n');
  console.log(`Validated ${report.length} lossless RGBA WebP icons, 256x256, identical rounded alpha geometry, opaque interiors, exact pixel round trips.`);
}
main().catch(e=>{console.error(e);process.exitCode=1;});
