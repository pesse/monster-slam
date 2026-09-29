const fs=require('fs'),path=require('path'),sharp=require('C:/Users/SamuelNitsche/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const root=path.resolve(__dirname,'..');
const parts=[['name_panel',0,200,610,245,600,180,55,24],['progress_panel',610,200,500,245,480,180,35,24],['medallion',1120,120,400,385,320,320,0,0],['castle',40,520,510,480,256,256,0,0],['level_plate',625,660,330,255,160,120,32,25],['progress_track',1020,730,505,130,400,48,25,12]];
(async()=>{
const src=path.join(__dirname,'atlas.png');if(!fs.existsSync(src))fs.copyFileSync('C:/Users/SamuelNitsche/.codex/generated_images/01a0ec42-5682-7e50-ae8e-6506f8be179c/exec-a5639f89-469a-4fa2-bec7-805ae662763f.png',src);
fs.mkdirSync(path.join(root,'textures'),{recursive:true});fs.mkdirSync(path.join(root,'styles'),{recursive:true});
const manifest={format:'lossless WebP RGBA',assets:{}};const layers=[];
for(let i=0;i<parts.length;i++){
const [name,x,y,w,h,ow,oh,sx,sy]=parts[i];
const {data,info}=await sharp(src).extract({left:x,top:y,width:w,height:h}).ensureAlpha().raw().toBuffer({resolveWithObject:true});
let l=w,t=h,r=-1,b=-1;for(let yy=0;yy<h;yy++)for(let xx=0;xx<w;xx++)if(data[(yy*w+xx)*4+3]>64){l=Math.min(l,xx);t=Math.min(t,yy);r=Math.max(r,xx);b=Math.max(b,yy);}
const file=path.join(root,'textures',name+'.webp');await sharp(data,{raw:info}).extract({left:l,top:t,width:r-l+1,height:b-t+1}).resize(ow,oh,{fit:'contain',background:'#00000000'}).webp({lossless:true}).toFile(file);
const stats=await sharp(file).stats();if(stats.channels[3].min!==0||stats.channels[3].max<240)throw Error('Bad alpha '+name);
manifest.assets[name]={path:'res://assets/ui/fortress/textures/'+name+'.webp',size:[ow,oh],slice:[sx,sy,sx,sy]};
if(sx)fs.writeFileSync(path.join(root,'styles',name+'.tres'),`[gd_resource type="StyleBoxTexture" load_steps=2 format=3]\n[ext_resource type="Texture2D" path="res://assets/ui/fortress/textures/${name}.webp" id="1"]\n[resource]\ntexture = ExtResource("1")\ntexture_margin_left = ${sx}.0\ntexture_margin_right = ${sx}.0\ntexture_margin_top = ${sy}.0\ntexture_margin_bottom = ${sy}.0\ncontent_margin_left = ${sx+8}.0\ncontent_margin_right = ${sx+8}.0\ncontent_margin_top = ${sy+8}.0\ncontent_margin_bottom = ${sy+8}.0\n`);
layers.push({input:await sharp(file).resize(280,160,{fit:'contain',background:'#00000000'}).png().toBuffer(),left:20+(i%3)*300,top:20+Math.floor(i/3)*200});
}
fs.writeFileSync(path.join(root,'manifest.json'),JSON.stringify(manifest,null,2));
await sharp({create:{width:920,height:420,channels:4,background:'#172131'}}).composite(layers).png().toFile(path.join(root,'preview/parts.png'));
console.log('6 RGBA WebPs and 4 nine-slice resources exported');
})();
