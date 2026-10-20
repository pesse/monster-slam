// R2: card_selected.webp is an immutable INPUT. Writes only cards/.
const path=require('node:path'),crypto=require('node:crypto');
const R=require('./raster.cjs');const {fs,clamp,raster,get,set,load,png,crop,paste,periodic,nine,seam,exportAsset,label,zoom}=R;
const root=path.resolve(__dirname,'..'),selectedFile=root+'/card_selected.webp';
const expectedGold='947d20640afba2af2d8365cfa5aa23aa5d73de5a9891c50afc89cc768a7dc58c';
const hash=f=>crypto.createHash('sha256').update(fs.readFileSync(f)).digest('hex');
const lum=p=>p[0]*.2126+p[1]*.7152+p[2]*.0722;
function stats(im){let a=[];for(let i=0;i<im.data.length;i+=4)a.push(lum(im.data.subarray(i,i+4)));let mean=a.reduce((a,b)=>a+b,0)/a.length;return {mean,sd:Math.sqrt(a.reduce((s,v)=>s+(v-mean)**2,0)/a.length)};}
const depth=(x,y)=>Math.min(x-15,y-15,176-x,176-y,(x+y-39)/Math.SQRT2,(191-x+y-39)/Math.SQRT2,(x+191-y-39)/Math.SQRT2,(382-x-y-39)/Math.SQRT2);
const falloff=d=>Math.pow(clamp(1-Math.max(0,d)/16,0,1),3);
function steelColor(L,frame){let o=frame?[-8,0,8*.2126/.0722]:[-11,.5,(11*.2126-.5*.7152)/.0722];let f=Math.min(1,L/20,(255-L)/28);return [...o.map(v=>L+v*f),255];}
async function material(wood){let im=await load(__dirname+'/steel-r2-generated.png',128,128),smooth=raster(128,128);
// Circular vertical low pass: long brush strokes, no short grain/speckles.
for(let y=0;y<128;y++)for(let x=0;x<128;x++){let L=0,w=0;for(let j=-9;j<=9;j++){let q=Math.exp(-j*j/32);L+=lum(get(im,x,(y+j+128)%128))*q;w+=q;}set(smooth,x,y,[L/w,L/w,L/w,255]);}
// Native-resolution insert retains fine brush grooves lost in the full-swatch downsample.
let native=crop(await load(__dirname+'/steel-r2-generated.png'),220,400,128,128);
let low=await load(await R.sharp(native.data,{raw:{width:128,height:128,channels:4}}).blur(3).png().toBuffer()),detail=raster(128,128);
for(let y=0;y<128;y++)for(let x=0;x<128;x++){let v=128+lum(get(native,x,y))-lum(get(low,x,y));set(detail,x,y,[v,v,v,255]);}
let a=stats(smooth),b=stats(wood),fine=stats(detail);for(let y=0;y<128;y++)for(let x=0;x<128;x++){let v=.6*(lum(get(smooth,x,y))-a.mean)/a.sd+.8*(lum(get(detail,x,y))-fine.mean)/fine.sd;set(smooth,x,y,steelColor(b.mean+v*b.sd,false));}
let tile=periodic(smooth,true,true,16),c=stats(tile);for(let y=0;y<128;y++)for(let x=0;x<128;x++)set(tile,x,y,steelColor(b.mean+(lum(get(tile,x,y))-c.mean)*b.sd/c.sd,false));
await png(tile,__dirname+'/steel-tile.png');return tile;}
function recolor(selected,wood,steel,hover=false){let out=raster(192,192);
for(let y=0;y<192;y++)for(let x=0;x<192;x++){
let p=get(selected,x,y),d=depth(x,y),t=clamp(d/3,0,1),f=falloff(d),shade=1-.42*f;
// Replace only the old material contribution. Preserve all frame detail pixels and original shadow residuals.
let oldL=lum(get(wood,(x+96)%128,(y+96)%128)),newL=lum(get(steel,(x+96)%128,(y+96)%128));
let L=lum(p)+(newL-oldL)*shade*t,q=steelColor(clamp(L),d<=0);
if(hover){let rim=1-t;for(let c=0;c<3;c++)q[c]=q[c]*(1+.13*rim)+2*rim+[2,9,17][c]*f*t;}
q[3]=p[3];if(!p[3])q=[0,0,0,0];set(out,x,y,q);
}return out;}
async function main(){let before=hash(selectedFile);if(before!==expectedGold)throw Error('Selected source changed; audit before rebuilding.');
let selected=await load(selectedFile),wood=crop(selected,32,32,128,128),steel=await material(wood),states={selected},checks={revision:2,selected_sha256_before:before};
for(let name of ['normal','hover']){let {im,checks:c}=await exportAsset(recolor(selected,wood,steel,name==='hover'),root,'card_'+name);states[name]=im;checks[name]=c;}
let old=JSON.parse(fs.readFileSync(root+'/preview/checks.json','utf8'));checks.selected={...old.selected};
for(let name of ['normal','hover','selected']){let im=states[name],c=checks[name];c.seams={};
for(let [key,rect,axis] of [['center_x',[32,32,128,128],'x'],['center_y',[32,32,128,128],'y'],['top_x',[32,0,128,32],'x'],['bottom_x',[32,160,128,32],'x'],['left_y',[0,32,32,128],'y'],['right_y',[160,32,32,128],'y']])c.seams[key]=seam(im,rect,axis);
c.alpha_mask_max_delta=0;c.center_opaque=true;for(let y=0;y<192;y++)for(let x=0;x<192;x++){c.alpha_mask_max_delta=Math.max(c.alpha_mask_max_delta,Math.abs(get(im,x,y)[3]-get(selected,x,y)[3]));if(x>=32&&x<160&&y>=32&&y<160&&get(im,x,y)[3]!==255)c.center_opaque=false;}
if(c.alpha_mask_max_delta||!c.center_opaque||Object.values(c.seams).some(s=>s.max_channel_delta))throw Error('Pixel contract '+name);}
let maxFrameDelta=0;for(let y=0;y<192;y++)for(let x=0;x<192;x++)if(depth(x,y)<=0&&get(selected,x,y)[3])maxFrameDelta=Math.max(maxFrameDelta,Math.abs(lum(get(states.normal,x,y))-lum(get(selected,x,y))));
checks.normal.frame_luminance_max_delta=maxFrameDelta;if(maxFrameDelta>.51)throw Error('Frame highlights changed');
checks.normal.geometry_source='card_selected.webp: pixel positions, bevels, rivets, alpha preserved; luminance-preserving steel recolor';
checks.normal.inner_shadow={inset:15,diagonal:39,falloff_extent:16,strength:.42,source:'same selected R1 construction; original luminance residual retained'};
checks.normal.center_luminance=stats(crop(states.normal,32,32,128,128));checks.selected.center_luminance=stats(wood);
checks.hover.center_identical_to_normal=true;for(let y=32;y<160;y++)for(let x=32;x<160;x++)if(get(states.normal,x,y).some((v,i)=>v!==get(states.hover,x,y)[i]))checks.hover.center_identical_to_normal=false;
if(!checks.hover.center_identical_to_normal)throw Error('Hover center changed');
let preview=raster(1152,1000,[6,12,22,255]);await label(preview,'KARTEN R2 / Gemeinsame Geometrie / Nine-Slice 32 / TILE x + y',24,30,19);
let cols=[32,320,608];for(let i=0;i<3;i++){let name=['normal','hover','selected'][i],x=cols[i];await label(preview,name.toUpperCase(),x,64,17,name==='selected'?'#f6d278':'#baceec');paste(preview,nine(states[name],200,224),x,82);await label(preview,'200 × 224',x,330);paste(preview,nine(states[name],240,280),x,352);await label(preview,'240 × 280',x,656);paste(preview,nine(states[name],64,96),x,680);await label(preview,'64 × 96',x+78,735);}
await label(preview,'Kachelgrenze / 3× nearest / Kreuzung x=160, y=160',24,816,17);for(let i=0;i<3;i++){let name=['normal','hover','selected'][i];paste(preview,await zoom(crop(nine(states[name],460,460),140,140,64,48),3),cols[i],834);}await png(preview,root+'/preview/cards.png');
let pair=raster(1000,320,[6,12,22,255]);paste(pair,raster(500,320,[222,227,234,255]),0,0);
for(let i=0;i<2;i++){let x=i*500,color=i?'#dce6f6':'#20324a';await label(pair,i?'DUNKLER HINTERGRUND':'HELLER HINTERGRUND',x+24,27,17,color);paste(pair,nine(states.normal,200,224),x+32,48);paste(pair,nine(states.selected,200,224),x+266,48);await label(pair,'NORMAL / Stahl',x+32,300,16,color);await label(pair,'SELECTED / Gold',x+266,300,16,color);}await png(pair,root+'/preview/pair.png');
let repeat=raster(1152,422,[6,12,22,255]);for(let i=0;i<3;i++){let name=['normal','hover','selected'][i],tile=crop(states[name],32,32,128,128);await label(repeat,name,8+i*384,24);for(let y=0;y<3;y++)for(let x=0;x<3;x++)paste(repeat,tile,i*384+x*128,38+y*128);}await png(repeat,root+'/preview/tiles-3x3.png');
checks.rendered_sizes=[[200,224],[240,280],[64,96]];checks.preview='Decoded final WebP; fixed corners, tiled edges/center, clipped partial tiles.';checks.selected_sha256_after=hash(selectedFile);checks.selected_unchanged=checks.selected_sha256_after===before;if(!checks.selected_unchanged)throw Error('Selected mutated');
checks.visual_review='Pair geometry identical on light/dark backgrounds. Steel brush straighter and more uniform than wood; blue speculars colder, shared highlight locations. Repetition inspectable in 3x3 sheet. Raster preview, not in-game capture.';
fs.writeFileSync(root+'/preview/checks.json',JSON.stringify(checks,null,2));console.log(JSON.stringify({selected_unchanged:checks.selected_unchanged,alpha_delta:checks.normal.alpha_mask_max_delta,frame_luminance_max_delta:maxFrameDelta,seams:'18 comparisons delta 0',normal_center:checks.normal.center_luminance,selected_center:checks.selected.center_luminance}));}
main().catch(e=>{console.error(e);process.exitCode=1});
