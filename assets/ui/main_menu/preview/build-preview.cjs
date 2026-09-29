const sharp=require(process.env.SHARP_MODULE || 'C:/Users/SamuelNitsche/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const path=require('node:path');
const root=path.resolve(__dirname,'..');
(async()=>{
const layers=[];
for(let col=0;col<2;col++){
 const x=col*620;
 const panel=await sharp({create:{width:620,height:880,channels:4,background:col?'#e8e4dc':'#202832'}}).png().toBuffer();
 layers.push({input:panel,left:x,top:0});
 for(const [f,y,w] of [['logo.webp',24,560],['buttons/button_normal.webp',330,560],['buttons/button_highlighted.webp',452,560],['panels/profile_panel.webp',578,560]]){
  layers.push({input:await sharp(path.join(root,f)).resize({width:w}).png().toBuffer(),left:x+30,top:y});
 }
 const icons=['play','skills','statistics','content','settings','expert','profile','switch_profile'];
 for(let i=0;i<8;i++)layers.push({input:await sharp(path.join(root,'icons',icons[i]+'.webp')).resize(58,58).png().toBuffer(),left:x+30+i*70,top:768});
}
await sharp({create:{width:1240,height:880,channels:4,background:'#202832'}}).composite(layers).png().toFile(path.join(__dirname,'contact-sheet.png'));
})();
