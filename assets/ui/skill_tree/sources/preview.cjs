const fs=require('fs'),path=require('path');
const sharp=require(process.env.SHARP_MODULE||'sharp');
const root=path.resolve(__dirname,'..');
(async()=>{
const layers=[];const labels=[];const m=JSON.parse(fs.readFileSync(path.join(root,'manifest.json')));
let n=0;
for(const key of Object.keys(m.assets)){
 const x=24+(n%7)*160,y=24+Math.floor(n/7)*170;
 layers.push({input:await sharp(path.join(root,key+'.webp')).resize(100,110,{fit:'inside'}).png().toBuffer(),left:x+20,top:y});
 labels.push(`<text x="${x}" y="${y+140}">${key.split('/').pop()}</text>`);n++;
}
layers.push({input:Buffer.from(`<svg width="1140" height="890"><g fill="#e5dcc5" font-size="13" font-family="sans-serif">${labels.join('')}</g></svg>`),left:0,top:0});
await sharp({create:{width:1140,height:890,channels:4,background:'#172131'}}).composite(layers).png().toFile(path.join(root,'preview/assets.png'));
})();
