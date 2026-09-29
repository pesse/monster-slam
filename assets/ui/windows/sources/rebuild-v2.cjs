const fs=require('node:fs'),path=require('node:path');
const sharp=require(process.env.SHARP_MODULE||'sharp');
const root=path.resolve(__dirname,'..'),P=n=>path.join(root,n);
const raw=async s=>s.ensureAlpha().raw().toBuffer({resolveWithObject:true});
const img=(d,w,h)=>sharp(d,{raw:{width:w,height:h,channels:4}});
const save=(s,n)=>s.webp({lossless:true,effort:6}).toFile(P(n));
const svg=(w,h,body)=>Buffer.from(`<svg width="${w}" height="${h}" xmlns="http://www.w3.org/2000/svg">${body}</svg>`);
async function nine(n,w,h,m=32,v=m){
 const s=await sharp(P(n)).metadata(),xs=[0,m,s.width-m,s.width],ys=[0,v,s.height-v,s.height],xd=[0,m,w-m,w],yd=[0,v,h-v,h],layers=[];
 for(let j=0;j<3;j++)for(let i=0;i<3;i++)layers.push({input:await sharp(P(n)).extract({left:xs[i],top:ys[j],width:xs[i+1]-xs[i],height:ys[j+1]-ys[j]}).resize(xd[i+1]-xd[i],yd[j+1]-yd[j],{fit:'fill'}).png().toBuffer(),left:xd[i],top:yd[j]});
 return sharp({create:{width:w,height:h,channels:4,background:'#0000'}}).composite(layers).png().toBuffer();
}
async function tone(n,out,f,add=0){const {data:d,info}=await raw(sharp(P(n)));for(let p=0;p<d.length;p+=4)for(let c=0;c<3;c++)d[p+c]=Math.min(255,Math.round(d[p+c]*f+add));await save(img(d,info.width,info.height),out);}
async function run(){
 const shell=await sharp(P('sources/shell-v2-generated.png')).extract({left:18,top:10,width:1638,height:920}).resize(1100,616).png().toBuffer();
 const {data:s}=await raw(sharp(shell));const pix=(x,y,c)=>s[(y*1100+x)*4+c];
 const base=[13,24,38,255],d=Buffer.alloc(256*256*4);
 for(let y=0;y<256;y++)for(let x=0;x<256;x++){
  const dx=Math.min(x,255-x),dy=Math.min(y,255-y),sx=x<32?x:x>=224?1100-256+x:550,sy=y<32?y:y>=224?616-256+y:308;
  const corner=dx<32&&dy<32,t=corner?Math.max(0,Math.min(1,(Math.max(dx,dy)-22)/9)):1;
  for(let c=0;c<4;c++){
   const edge=dx<10&&dx<dy?pix(sx,308,c):dy<10?pix(550,sy,c):base[c];
   d[(y*256+x)*4+c]=Math.round(pix(sx,sy,c)*(1-t)+edge*t);
  }
 }
 await save(img(d,256,256),'window_panel_compact.webp');
 // Shared top/side frame geometry. No second bottom frame or lower chamfer.
 const td=Buffer.alloc(512*64*4),divider=[[12,21,32,255],[35,48,64,255],[69,86,109,255],[13,23,36,255]];
 for(let y=0;y<64;y++)for(let x=0;x<512;x++){
  const px=x<32?x:x>=480?x-256:128;
  for(let c=0;c<4;c++){
   let q=y<32?d[(y*256+px)*4+c]:d[(100*256+px)*4+c];
   if(x>=10&&x<502&&y>=10){q=y>=60?divider[y-60][c]:[16,27,42,255][c];if(y<32&&(x<32||x>=480))q=d[(y*256+px)*4+c];}
   td[(y*512+x)*4+c]=q;
  }
 }
 await save(img(td,512,64),'title_bar.webp');
 // Joint plates extend below the divider and must not be stretched.
 for(const [side,left] of [['left',0],['right',1076]]){
  let mask=svg(24,24,'<path d="M0 3L7 0L21 12L7 24L0 21Z" fill="white"/>');
  if(side==='right')mask=await sharp(mask).flop().png().toBuffer();
  await save(sharp(shell).extract({left,top:53,width:24,height:24}).composite([{input:mask,blend:'dest-in'}]),'title_joint_'+side+'.webp');
 }
 // Seamless low-contrast material layer, mirrored at tile boundaries. Alpha
 // blends over the base navy. It is tiled independently of all nine-slices.
 const patch=await sharp(shell).extract({left:370,top:210,width:256,height:256}).png().toBuffer();
 const tile=await sharp({create:{width:512,height:512,channels:4,background:'#0000'}}).composite([
  {input:patch,left:0,top:0},{input:await sharp(patch).flop().png().toBuffer(),left:256,top:0},
  {input:await sharp(patch).flip().png().toBuffer(),left:0,top:256},{input:await sharp(patch).flip().flop().png().toBuffer(),left:256,top:256}
 ]).png().toBuffer();
 const {data:t}=await raw(sharp(tile));for(let p=3;p<t.length;p+=4)t[p]=190;
 await save(img(t,512,512),'window_surface.webp');
 const close=await sharp(P('sources/close-v2-generated.png')).trim({background:'#0000',threshold:10}).resize(96,96,{fit:'contain',background:'#0000'}).png().toBuffer();
 await save(sharp({create:{width:128,height:128,channels:4,background:'#0000'}}).composite([{input:close,left:16,top:16}]),'close.webp');
 await tone('close.webp','close_hover.webp',1.12,6);await tone('close.webp','close_pressed.webp',.67);
 await save(sharp(await nine('window_panel_compact.webp',176,176)).resize(44,44),'tool_button_normal.webp');
 await tone('tool_button_normal.webp','tool_button_hover.webp',1.3,7);await tone('tool_button_normal.webp','tool_button_pressed.webp',.7);await tone('tool_button_normal.webp','tool_button_disabled.webp',.5,2);
 // Surface clipped inside the frame (including corner diagonals).
 const tiles=[];for(let y=0;y<616;y+=512)for(let x=0;x<1100;x+=512)tiles.push({input:await sharp(P('window_surface.webp')).extract({left:0,top:0,width:Math.min(512,1100-x),height:Math.min(512,616-y)}).png().toBuffer(),left:x,top:y});
 const material=await sharp({create:{width:1100,height:616,channels:4,background:'#0000'}}).composite(tiles).png().toBuffer();
 const mask=svg(1100,616,'<path d="M20 9H1080L1091 20V596L1080 607H20L9 596V20Z" fill="white"/>');
 const clipped=await sharp(material).composite([{input:mask,blend:'dest-in'}]).png().toBuffer();
 const headerMaterial=await sharp(material).extract({left:0,top:0,width:1100,height:64}).composite([{input:svg(1100,64,'<path d="M20 10H1080L1090 20V59H10V20Z" fill="white" opacity="0.48"/>'),blend:'dest-in'}]).png().toBuffer();
 const plateL=await sharp(P('title_joint_left.webp')).png().toBuffer(),plateR=await sharp(P('title_joint_right.webp')).png().toBuffer();
 const layers=[{input:await nine('window_panel_compact.webp',1100,616),left:26,top:16},{input:clipped,left:26,top:16},{input:await nine('title_bar.webp',1100,64,32,8),left:26,top:16},{input:headerMaterial,left:26,top:16},{input:plateL,left:26,top:67},{input:plateR,left:1102,top:67}];
 // All glyphs below are PREVIEW ONLY; runtime assets remain unlabelled.
 const book='<path d="M50 32Q62 28 73 34Q85 28 97 32L97 64Q84 61 73 67Q61 61 50 64Z" fill="#aeb8ce" stroke="#4c566b" stroke-width="3"/><path d="M52 31Q64 28 72 34V62Q62 57 52 61ZM75 34Q85 28 95 31V61Q85 57 75 62Z" fill="#d2d3df"/><path d="M73 34V65" stroke="#67738b" stroke-width="2"/>';
 const labels=svg(1152,648,`<defs><linearGradient id="silver" x2="0" y2="1"><stop stop-color="#fff"/><stop offset=".5" stop-color="#e7e7f4"/><stop offset="1" stop-color="#8899bf"/></linearGradient></defs>${book}<text x="115" y="59" font-family="DejaVu Sans,Arial" font-size="32" font-weight="bold" stroke="#050a14" stroke-width="4" paint-order="stroke" fill="url(#silver)">FÄHIGKEITEN</text><text x="931" y="54" font-family="DejaVu Sans,Arial" font-size="17" font-weight="bold" fill="#ffd958">995 Skillpunkte</text>`);
 layers.push({input:labels,left:0,top:0},{input:await sharp(P('../skill_tree/icons/skill_point.webp')).resize(25,25).png().toBuffer(),left:895,top:32},{input:await sharp(P('close.webp')).resize(32,32).png().toBuffer(),left:1080,top:30});
 for(let i=0;i<4;i++)layers.push({input:await sharp(P('tool_button_normal.webp')).png().toBuffer(),left:854+i*58,top:538});
 layers.push({input:svg(1152,648,'<g stroke="#d1d9ec" stroke-width="2" fill="none"><path d="M869 560H883 M927 560H941 M934 553V567 M982 555V549H988 M998 549H1004V555 M982 565V571H988 M998 571H1004V565 M1045 566A9 9 0 1 0 1045 554 M1044 548V555H1051"/></g>'),left:0,top:0});
 const preview=await sharp({create:{width:1152,height:648,channels:4,background:'#101720'}}).composite(layers).png().toBuffer();
 fs.writeFileSync(P('preview/skill-tree-window-1152x648.png'),preview);await sharp(preview).resize(1920,1080).png().toFile(P('preview/skill-tree-window-1920x1080.png'));
 const concept=await sharp(P('../skill_tree/concept/skill-tree-v5.webp')).resize(1152,648).extract({left:0,top:0,width:1152,height:100}).png().toBuffer();
 const current=await sharp(preview).extract({left:0,top:0,width:1152,height:100}).png().toBuffer();
 await sharp({create:{width:1152,height:208,channels:4,background:'#090d14'}}).composite([{input:concept,left:0,top:0},{input:current,left:0,top:108}]).png().toFile(P('preview/concept-header-comparison.png'));
 const states=[];for(let i=0;i<3;i++)states.push({input:await sharp(P(['close.webp','close_hover.webp','close_pressed.webp'][i])).png().toBuffer(),left:16+i*144,top:16});
 await sharp({create:{width:448,height:160,channels:4,background:'#111c2b'}}).composite(states).png().toFile(P('preview/close-states.png'));
 const M=JSON.parse(fs.readFileSync(P('manifest.json'),'utf8'));M.revision=2;
 M.panel.edge_profile='constant straight strips; material separate';M.panel.content_padding=26;
 M.title_bar={texture:'title_bar.webp',source_size:[512,64],slice:[32,8,32,8],fixed_height:64,horizontal_only:true,recommended_width:[800,1100],content_padding:[24,12,24,12],icon_box:[40,40],icon_title_gap:12,divider_y:62,right_group:{close_box:[40,40],right_inset:12,points_close_gap:20,reserved_width:230},joints:{left:'title_joint_left.webp',right:'title_joint_right.webp',source_size:[24,24],position_left:[0,51],position_right:['width-24',51],slice:null}};
 M.surface={texture:'window_surface.webp',source_size:[512,512],repeat:true,slice:null,alpha:190,clip:'inside panel metal, inset 9px, chamfer 11px',header_opacity:.48,header_clip:'inside face; y=10..59'};
 M.tool_buttons.slice=[8,8,8,8];M.tool_buttons.content_padding=7;M.tool_buttons.rim_px=2;
 M.preview.files.push('preview/concept-header-comparison.png');M.preview.files=[...new Set(M.preview.files)];M.layer_order=['panel','surface clipped to inner face','title_bar at 0,0','optional surface clipped to header face','title joints at y=51','game icons and labels'];
 fs.writeFileSync(P('manifest.json'),JSON.stringify(M,null,2)+'\n');
 const files=['window_panel_compact.webp','title_bar.webp','title_joint_left.webp','title_joint_right.webp','window_surface.webp',...M.close.textures,...M.tool_buttons.textures],checks=[];
 for(const f of files){const meta=await sharp(P(f)).metadata();if(!meta.hasAlpha||!fs.readFileSync(P(f)).includes(Buffer.from('VP8L')))throw Error('Encoding '+f);checks.push({file:f,width:meta.width,height:meta.height,alpha:true,lossless:true});}
 for(const f of ['window_panel_compact.webp','title_bar.webp']){const {data:a,info}=await raw(sharp(P(f)));for(let y=0;y<info.height;y++)for(let x=32;x<info.width-32;x++)for(let c=0;c<4;c++)if(a[(y*info.width+x)*4+c]!==a[(y*info.width+32)*4+c])throw Error('Horizontal strip '+f);if(f.startsWith('window'))for(let y=32;y<224;y++)for(let x=0;x<256;x++)for(let c=0;c<4;c++)if(a[(y*256+x)*4+c]!==a[(32*256+x)*4+c])throw Error('Vertical strip');}
 const {data:a}=await raw(sharp(P('close.webp')));for(const f of M.close.textures.slice(1)){const {data:b}=await raw(sharp(P(f)));for(let p=3;p<a.length;p+=4)if(a[p]!==b[p])throw Error('X alpha');}
 fs.writeFileSync(P('preview/asset-checks.json'),JSON.stringify({revision:2,checks,straight_edges_pixel_identical:true,close_alpha_identical:true,material_separate:true},null,2)+'\n');
 console.log('Revision 2: '+checks.length+' lossless alpha textures; strip and state checks passed.');
}
run().catch(e=>{console.error(e);process.exitCode=1;});
