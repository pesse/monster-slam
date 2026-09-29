const fs=require('node:fs'),path=require('node:path');
const sharp=require(process.env.SHARP_MODULE||'sharp');
const root=path.resolve(__dirname,'..');
function write(name,text){fs.mkdirSync(path.dirname(path.join(root,name)),{recursive:true});fs.writeFileSync(path.join(root,name),text);}
function textureStyle(file,margin,scale,padding,center=true){return `[gd_resource type="StyleBoxTexture" load_steps=2 format=3]\n\n[ext_resource type="Texture2D" path="res://assets/ui/${file}" id="1"]\n\n[resource]\ntexture = ExtResource("1")\ntexture_margin_left = ${margin}.0\ntexture_margin_top = ${margin}.0\ntexture_margin_right = ${margin}.0\ntexture_margin_bottom = ${margin}.0\naxis_stretch_horizontal = 0\naxis_stretch_vertical = 0\naxis_stretch_mode = 0\ndraw_center = ${center}\ncontent_margin_left = ${padding}.0\ncontent_margin_top = ${padding}.0\ncontent_margin_right = ${padding}.0\ncontent_margin_bottom = ${padding}.0\n` .replace('axis_stretch_mode = 0\n','') + `\n`;}
(async()=>{
const input=path.join(__dirname,'window-generated.png');
const {data,info}=await sharp(input).ensureAlpha().raw().toBuffer({resolveWithObject:true});
let xs=[],ys=[];
for(let y=0;y<info.height;y++){let count=0;for(let x=0;x<info.width;x++)if(data[(y*info.width+x)*4+3]>128)count++;if(count>info.width*.08)ys.push(y);}
for(let x=0;x<info.width;x++){let count=0;for(let y=0;y<info.height;y++)if(data[(y*info.width+x)*4+3]>128)count++;if(count>info.height*.08)xs.push(x);}
const left=Math.max(0,xs[0]-3),top=Math.max(0,ys[0]-3);
await sharp(input).extract({left,top,width:Math.min(info.width,xs.at(-1)+4)-left,height:Math.min(info.height,ys.at(-1)+4)-top}).resize(512,512).webp({lossless:true,effort:6}).toFile(path.join(root,'window_panel.webp'));
// Runtime texture at 256 px gives 32 px nine-slice corners without scaling the frame.
await sharp(path.join(root,'window_panel.webp')).resize(256,256).webp({lossless:true,effort:6}).toFile(path.join(root,'window_panel_compact.webp'));
write('styles/window.tres',textureStyle('windows/window_panel_compact.webp',32,1,26));
write('styles/window_large.tres',textureStyle('windows/window_panel.webp',64,1,48));
write('styles/frame_only.tres',textureStyle('windows/window_panel_compact.webp',32,1,26,false));
for(const state of ['normal','highlighted']){
 await sharp(path.join(root,'../main_menu/buttons/button_'+state+'.webp')).resize(520,96).webp({lossless:true,effort:6}).toFile(path.join(root,'tab_'+state+'.webp'));
 write('styles/tab_'+state+'.tres',textureStyle('windows/tab_'+state+'.webp',28,1,16));
}
write('manifest.json',JSON.stringify({format:'lossless WebP RGBA',panel:{texture:'window_panel_compact.webp',source_size:[256,256],slice:[32,32,32,32],content_padding:26,recommended_minimum:[280,180]},large:{texture:'window_panel.webp',source_size:[512,512],slice:[64,64,64,64],content_padding:48},tabs:{textures:['tab_normal.webp','tab_highlighted.webp'],source_size:[520,96],slice:[28,28,28,28],content_padding:16}},null,2)+'\n');
for(const file of ['window_panel.webp','window_panel_compact.webp','tab_normal.webp','tab_highlighted.webp']){const m=await sharp(path.join(root,file)).metadata();if(!m.hasAlpha)throw Error(file+' missing alpha');console.log(file,m.width,m.height);}
})();
