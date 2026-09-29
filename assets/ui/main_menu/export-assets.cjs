const fs = require('node:fs');
const path = require('node:path');
const sharp = require(process.env.SHARP_MODULE || 'C:/Users/SamuelNitsche/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const root = __dirname;
const src = path.join(root, 'sources');
const inputs = {
  logo: 'exec-b1afa959-68e2-4d12-beed-3513e6f2494a.png',
  button_normal: 'exec-e11f82b6-4386-4136-808d-1486213c4546.png',
  button_highlighted: 'exec-782dec2f-986b-42db-b4b7-b83cab08362a.png',
  icons: 'exec-8b9a596a-f05c-4b06-b95b-11f7fa5cfe20.png',
  profile_panel: 'exec-13988538-7873-42a0-903b-45bf53dc2bde.png'
};
const generated = process.argv[2];
const transparent = {r:0,g:0,b:0,alpha:0};
const manifest = {format:'lossless WebP RGBA', assets:{}};
async function bounds(input) {
  const {data,info} = await sharp(input).ensureAlpha().raw().toBuffer({resolveWithObject:true});
  let left=info.width,top=info.height,right=-1,bottom=-1;
  for(let y=0;y<info.height;y++) for(let x=0;x<info.width;x++) {
    if(data[(y*info.width+x)*4+3]>8) {left=Math.min(left,x);top=Math.min(top,y);right=Math.max(right,x);bottom=Math.max(bottom,y);}
  }
  if(right<0) throw new Error('Empty alpha');
  left=Math.max(0,left-3);top=Math.max(0,top-3);right=Math.min(info.width-1,right+3);bottom=Math.min(info.height-1,bottom+3);
  return {left,top,width:right-left+1,height:bottom-top+1};
}
async function save(name, pipeline, notes) {
  const file=path.join(root,name+'.webp');
  fs.mkdirSync(path.dirname(file),{recursive:true});
  await pipeline.webp({lossless:true,effort:6}).toFile(file);
  const meta=await sharp(file).metadata();
  const stats=await sharp(file).stats();
  if(!meta.hasAlpha || stats.channels[3].min!==0 || stats.channels[3].max!==255) throw new Error('Missing alpha: '+name);
  manifest.assets[name]={file:name+'.webp',width:meta.width,height:meta.height,notes};
}
(async()=>{
  fs.mkdirSync(src,{recursive:true});
  for(const [key,value] of Object.entries(inputs)) {
    const dest=path.join(src,key+'.png');
    if(!fs.existsSync(dest)) {
      if(!generated) throw new Error('Source missing: '+dest);
      fs.copyFileSync(path.join(generated,value),dest);
    }
  }
  const normal=path.join(src,'button_normal.png'),hi=path.join(src,'button_highlighted.png');
  const nb=await bounds(normal),hb=await bounds(hi);
  const union={left:Math.min(nb.left,hb.left),top:Math.min(nb.top,hb.top)};
  union.width=Math.max(nb.left+nb.width,hb.left+hb.width)-union.left;
  union.height=Math.max(nb.top+nb.height,hb.top+hb.height)-union.top;
  for(const [name,file] of [['button_normal',normal],['button_highlighted',hi]]) {
    await save('buttons/'+name,sharp(file).extract(union).resize(1024,176,{fit:'fill'}).extend({top:8,bottom:8,left:8,right:8,background:transparent}), 'Gemeinsamer Quellausschnitt und identische 1040×192-Leinwand. Ohne Text/Icons.');
  }
  for(const [key,width] of [['logo',1200],['profile_panel',1000]]) {
    const file=path.join(src,key+'.png');
    await save(key==='logo'?'logo':'panels/profile_panel',sharp(file).extract(await bounds(file)).resize({width}).extend({top:8,bottom:8,left:8,right:8,background:transparent}),key==='logo'?'Logo mit transparenter Umgebung.':'Leere Profilplakette mit Tab rechts unten; Inhalt separat zeichnen.');
  }
  const atlas=path.join(src,'icons.png'),meta=await sharp(atlas).metadata();
  const names=['play','skills','statistics','content','settings','expert','profile','switch_profile'];
  for(let i=0;i<names.length;i++) {
    const col=i%4,row=Math.floor(i/4),left=Math.round(col*meta.width/4),top=Math.round(row*meta.height/2);
    const cell=await sharp(atlas).extract({left,top,width:Math.round((col+1)*meta.width/4)-left,height:Math.round((row+1)*meta.height/2)-top}).png().toBuffer();
    await save('icons/'+names[i],sharp(cell).extract(await bounds(cell)).resize(224,224,{fit:'contain',background:transparent}).extend({top:16,bottom:16,left:16,right:16,background:transparent}),'256×256, zentriert, für Anzeige mit 40–64 px.');
  }
  fs.writeFileSync(path.join(root,'manifest.json'),JSON.stringify(manifest,null,2)+'\n');
  console.log(JSON.stringify(manifest,null,2));
})();
