// Run: node ui/windows/header/sources/export.cjs. Writes only header/.
const path=require('node:path');
const {fs,sharp,clamp,raster,get,set,mix,load,png,crop,paste,periodic,nine,seam,exportAsset,label,zoom}=require('./raster.cjs');
const root=path.resolve(__dirname,'..'),win=path.resolve(root,'..');
async function main(){fs.mkdirSync(root+'/preview',{recursive:true});fs.writeFileSync(__dirname+'/.gdignore','');
 const source=await load(win+'/folder_tabs/sources/concept-v1.png');
 const concept=await load(win+'/folder_tabs/sources/concept-v1.png',1152,384);await png(concept,__dirname+'/concept-1152.png');
 // Exact text/icon-free original header swatch. Vertical resize only for the new 64px contract.
 const sourceRegion=crop(source,680,82,1330,128);await png(sourceRegion,__dirname+'/header-concept-region.png');
 let swatch=await load(await sharp(sourceRegion.data,{raw:{width:sourceRegion.w,height:sourceRegion.h,channels:4}}).png().toBuffer(),448,54);
 swatch=periodic(swatch,true,false,24);await png(swatch,__dirname+'/header-tile.png');
 const original=await load(win+'/title_bar.webp');let bar={...original,data:Buffer.from(original.data)};
 for(let y=8;y<62;y++)for(let x=0;x<512;x++){
  // Keep original side/corner bevels. Replace only the interior.
  let d=Math.min(x-9,502-x,(x+y-27)/Math.SQRT2,(511-x+y-27)/Math.SQRT2);
  let t=clamp(d/3,0,1);if(!t)continue;
  const p=get(swatch,(x-32+448)%448,y-8);let v=(y-8)/53;
  // Restrained upper illumination and a dark foot, as in the approved concept.
  let k=1.07-.16*v;let q=[p[0]*k,p[1]*k,p[2]*k,255];
  if(y===8)q=mix(q,[53,75,110,255],.27);
  set(bar,x,y,mix(get(original,x,y),q,t));
 }
 // Straight top bevel in the original is already horizontally constant.
 const titleResult=await exportAsset(bar,root,'title_bar');bar=titleResult.im;
 const ringSrc=crop(concept,40,43,68,68);await png(ringSrc,__dirname+'/medallion-concept-region.png');
 const ring=await load(await sharp(ringSrc.data,{raw:{width:68,height:68,channels:4}}).png().toBuffer(),64,64);let med=raster(64,64);
 for(let y=0;y<64;y++)for(let x=0;x<64;x++){
  let dx=x-31.5,dy=y-31.5,r=Math.hypot(dx,dy),p=get(ring,x,y);
  // Trophy is removed from the source; supplied runtime trophy is composited only in preview.
  let base=[6+(1-y/64)*4,14+(1-y/64)*6,24+(1-y/64)*8,255];
  let interior=clamp((25.7-r)/.8,0,1);p=mix(p,base,interior);
  p[3]=255*clamp(31.5-r,0,1);if(r>30.6)p[3]*=.55;
  if(!p[3])p=[0,0,0,0];set(med,x,y,p);
 }
 const medResult=await exportAsset(med,root,'title_medallion');med=medResult.im;
 const checks={title_bar:titleResult.checks,title_medallion:medResult.checks};
 checks.title_medallion.interior_radius_24_opaque=true;checks.title_medallion.exterior_radius_31_5_transparent=true;
 for(let y=0;y<64;y++)for(let x=0;x<64;x++){let r=Math.hypot(x-31.5,y-31.5),a=get(med,x,y)[3];if(r<24&&a!==255)checks.title_medallion.interior_radius_24_opaque=false;if(r>=31.5&&a!==0)checks.title_medallion.exterior_radius_31_5_transparent=false;}
 if(!checks.title_medallion.interior_radius_24_opaque||!checks.title_medallion.exterior_radius_31_5_transparent)throw Error('Medallion alpha contract');
 checks.title_bar.horizontal_seam_all_64_rows=seam(bar,[32,0,448,64],'x');
 let topDiff=0,bottomDiff=0;for(let y=0;y<64;y++)for(let x=0;x<512;x++)for(let c=0;c<4;c++){let p=get(bar,x,y),q=get(original,x,y);if(c<3&&!p[3]&&!q[3])continue;let d=Math.abs(p[c]-q[c]);if(y<8)topDiff=Math.max(topDiff,d);if(y>=62)bottomDiff=Math.max(bottomDiff,d);}
 checks.title_bar.original_top_8_rows_max_delta=topDiff;checks.title_bar.original_separator_rows_62_63_max_delta=bottomDiff;
 if(checks.title_bar.horizontal_seam_all_64_rows.max_channel_delta||topDiff||bottomDiff)throw Error('Header geometry/seam contract failed');
 // 64px height, x tiling only; the top/bottom 8px slices remain 1:1.
 let preview=raster(1152,388,[6,12,22,255]);const trophy=await load(path.resolve(win,'../statistics/icons/records_trophy.webp'),40,40);
 for(let [width,y] of [[1152,34],[640,140]]){await label(preview,'EXPORT '+width+' × 64 / Medaillon 64 / Icon 40',12,y-10,16);paste(preview,nine(bar,width,64,[32,32,8,8]),0,y);paste(preview,med,18,y);paste(preview,trophy,30,y+12);
  // Text overlay only, using the game's actual Fira Sans font when available.
  const font=path.resolve(win,'../../fonts/fira_sans/FiraSans-SemiBold.ttf');
  let text=await sharp({text:{text:'<span foreground="#edf0f7">STATISTIK</span>',font:'Fira Sans SemiBold 36',fontfile:font,rgba:true,dpi:72}}).png().toBuffer();paste(preview,await load(text),96,y+14);
 }
 await label(preview,'FREIGEGEBENES KONZEPT / Original auf 1152 px skaliert',12,246,16);paste(preview,crop(concept,0,29,1152,90),0,260);await png(preview,root+'/preview/header.png');
 let detail=raster(1152,200,[6,12,22,255]);paste(detail,await zoom(crop(nine(bar,1152,64,[32,32,8,8]),448,0,80,64),3),0,4);paste(detail,await zoom(med,3),286,4);await label(detail,'3× / Kachelgrenze x=480',504,54,20);await label(detail,'3× / Medaillon ohne Icon',504,94,20);await png(detail,root+'/preview/details.png');
 checks.rendered_widths=[480,640,1100,1152];checks.every_width_480_to_1100=true;
 for(let w=480;w<=1100;w++){let im=nine(bar,w,64,[32,32,8,8]);if(im.w!==w||im.h!==64)throw Error('Width');}
 fs.writeFileSync(root+'/preview/checks.json',JSON.stringify(checks,null,2));console.log('header: RGBA, VP8L, lossless roundtrip, x32/x479, original top + separator PASS');
}
main().catch(e=>{console.error(e);process.exitCode=1});
