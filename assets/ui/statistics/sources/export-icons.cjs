const fs=require('fs'),path=require('path');
const sharp=require(process.env.SHARP_MODULE||'sharp');
const root=path.resolve(__dirname,'..'),src=path.join(__dirname,'icons-atlas.png');
const names=['streak_flame','correct_check','records_trophy','gold_coins','treasure_chest','activity_coin'];
(async()=>{
fs.mkdirSync(path.join(root,'icons'),{recursive:true});
const meta=await sharp(src).metadata(),layers=[],manifest={format:'lossless WebP RGBA',icons:{}};
for(let i=0;i<6;i++){
 const w=meta.width/3,h=meta.height/2;
 const cell=await sharp(src).extract({left:(i%3)*w,top:Math.floor(i/3)*h,width:w,height:h}).ensureAlpha().raw().toBuffer({resolveWithObject:true});
 let l=w,t=h,r=-1,b=-1;
 for(let y=0;y<h;y++)for(let x=0;x<w;x++)if(cell.data[(y*w+x)*4+3]>32){l=Math.min(l,x);t=Math.min(t,y);r=Math.max(r,x);b=Math.max(b,y);}
 if(r<0)throw Error('empty');
 const icon=await sharp(cell.data,{raw:cell.info}).extract({left:l,top:t,width:r-l+1,height:b-t+1}).resize(208,208,{fit:'contain',background:'#00000000'}).extend({left:24,right:24,top:24,bottom:24,background:'#00000000'}).webp({lossless:true}).toBuffer();
 const out=path.join(root,'icons',names[i]+'.webp');fs.writeFileSync(out,icon);
 const stats=await sharp(out).stats();if(stats.channels[3].min!==0||stats.channels[3].max<240)throw Error('Bad alpha');
 manifest.icons[names[i]]={path:'res://assets/ui/statistics/icons/'+names[i]+'.webp',width:256,height:256};
 layers.push({input:await sharp(icon).resize(128,128).png().toBuffer(),left:32+(i%3)*220,top:24+Math.floor(i/3)*190});
}
manifest.reuse={level_star:'res://assets/ui/skill_tree/icons/skill_point.webp',medallion:'res://assets/ui/skill_tree/medallions/available.webp',hover_ring:'res://assets/ui/skill_tree/medallions/focus_ring.webp',tooltip:'res://assets/ui/tooltip/tooltip_shell.tscn'};
fs.writeFileSync(path.join(root,'manifest.json'),JSON.stringify(manifest,null,2)+'\n');
const labels=names.map((n,i)=>`<text x="${24+(i%3)*220}" y="${177+Math.floor(i/3)*190}">${n}</text>`).join('');
layers.push({input:Buffer.from(`<svg width="660" height="390"><g fill="#e8e8e8" font-family="sans-serif" font-size="16">${labels}</g></svg>`),left:0,top:0});
await sharp({create:{width:660,height:390,channels:4,background:'#172131'}}).composite(layers).png().toFile(path.join(root,'preview/icons.png'));
console.log('PASS: 6 transparent 256x256 WebP icons');
})();
