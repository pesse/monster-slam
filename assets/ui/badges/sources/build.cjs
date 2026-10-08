const fs = require('fs');
const path = require('path');
const sharp = require(process.env.BADGES_SHARP || 'C:/Users/SamuelNitsche/AppData/Local/OpenAI/Codex/runtimes/cua_node/98614bf36dff477b/bin/node_modules/sharp');
const root = path.resolve(__dirname, '..');
const names = ['bronze','silver','gold','diamond','comeback','better','revenge','catch_up'];
async function main() {
  const reports = [];
  const previews = [];
  for (const [index,name] of names.entries()) {
    const source = path.join(__dirname, name+'.png');
    const {data, info} = await sharp(source).ensureAlpha().raw().toBuffer({resolveWithObject:true});
    const {width:w,height:h} = info;
    const alpha=(x,y)=>data[(y*w+x)*4+3];
    const cx=Math.floor(w/2);
    let top=0; while (top<h && alpha(cx,top)<128) top++;
    let bottom=top; while(bottom+1<h && alpha(cx,bottom+1)>=128) bottom++;
    const cy=Math.round((top+bottom)/2);
    let left=0; while(left<w && alpha(left,cy)<128) left++;
    let right=w-1; while(right>=0 && alpha(right,cy)<128) right--;
    let last=h-1;
    outer: for(;last>=0;last--) {for(let x=0;x<w;x++) if(alpha(x,last)>=128) break outer;}
    const dw=right-left+1;
    const outW=Math.round(w*208/dw);
    const outLeft=Math.round(128-(left+dw/2)*208/dw);
    // Disc and lower ribbon region are normalized separately to retain the
    // exact circle and reach the requested ribbon end at logical y=310.
    const disc=await sharp(source).extract({left:0,top,width:w,height:bottom-top+1}).resize(outW,208,{fit:'fill',kernel:'lanczos3'}).png().toBuffer();
    const tails=await sharp(source).extract({left:0,top:bottom+1,width:w,height:last-bottom}).resize(outW,86,{fit:'fill',kernel:'lanczos3'}).png().toBuffer();
    const file=path.join(root,name+'.webp');
    await sharp({create:{width:256,height:320,channels:4,background:'#00000000'}}).composite([{input:disc,left:outLeft,top:16},{input:tails,left:outLeft,top:224}]).webp({lossless:true,effort:6}).toFile(file);
    const meta=await sharp(file).metadata();
    const decoded=await sharp(file).raw().toBuffer();
    const bytes=fs.readFileSync(file);
    if(meta.width!==256 || meta.height!==320 || !meta.hasAlpha || !bytes.includes(Buffer.from('VP8L'))) throw Error(name+': invalid output');
    let transparent=0,opaque=0;for(let i=3;i<decoded.length;i+=4){transparent+=decoded[i]===0;opaque+=decoded[i]===255;}
    if(!transparent || !opaque) throw Error(name+': invalid alpha');
    reports.push({name,sourceSize:[w,h],sourceDiscBounds:[left,top,right,bottom],sourceBottom:last,outputSize:[256,320],discCenter:[128,120],discRadius:104,ribbonBottom:310,transparentPixels:transparent,opaquePixels:opaque,lossless:true});
    previews.push({input:await sharp(file).png().toBuffer(),left:index*256,top:0});
  }
  await sharp({create:{width:2048,height:320,channels:4,background:'#202733'}}).composite(previews).png().toFile(path.join(root,'preview','all_badges.png'));
  await sharp({create:{width:2048,height:320,channels:4,background:'#00000000'}}).composite(previews).png().toFile(path.join(root,'preview','all_badges_transparent.png'));
  fs.writeFileSync(path.join(__dirname,'validation.json'),JSON.stringify(reports,null,2)+'\n');
  console.log(JSON.stringify(reports,null,2));
}
main().catch(e=>{console.error(e);process.exitCode=1;});
