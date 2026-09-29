const fs=require('node:fs'), path=require('node:path'), crypto=require('node:crypto');
const sharp=require(process.env.SHARP_MODULE||'sharp');
const root=path.resolve(__dirname,'..');
const generated=process.argv[2];
const clear={r:0,g:0,b:0,alpha:0};
const files={scout:'exec-e9eaa750-477d-4bae-9139-8e849ccb1f27.png',healing:'exec-d5b41bf4-a222-4495-8116-b3cb6cad190a.png',bulwark:'exec-69d38014-f55c-491a-a98d-24cba0217626.png',time:'exec-34fe8707-f728-44ce-89ed-b57a85a3b2af.png',medallions:'exec-4ea95b24-f891-4f82-9f1c-9fda69794701.png'};
const grid={
 scout:['scout_eye','scout_boots','scout_feather','scout_winged_boots','scout_charge','scout_bow'],
 healing:['healing_bandage','healing_staff','healing_ritual','healing_tent','healing_dove','skill_point'],
 bulwark:['bulwark_palisade','bulwark_wall','bulwark_gate','bulwark_bastion','bulwark_portcullis','defense_shield'],
 time:['time_hourglass','time_wind','time_web','time_pause','time_rift','reset']
};
const idMap={
 'skill.scout.root':'scout_eye','skill.scout.boots':'scout_boots','skill.scout.light':'scout_feather','skill.scout.sprint':'scout_winged_boots','skill.scout.charge':'scout_charge','skill.scout.bow':'scout_bow',
 'skill.heal.root':'healing_bandage','skill.heal.care':'healing_staff','skill.heal.rite':'healing_ritual','skill.heal.ward':'healing_tent','skill.heal.bless':'healing_dove',
 'skill.armor.root':'bulwark_palisade','skill.armor.stone':'bulwark_wall','skill.armor.gate':'bulwark_gate','skill.armor.bastion':'bulwark_bastion','skill.armor.portcullis':'bulwark_portcullis',
 'skill.time.root':'time_hourglass','skill.time.long':'time_wind','skill.time.deep':'time_web','skill.time.still':'time_pause','skill.time.rift':'time_rift'
};
const manifest={version:1,format:'lossless WebP RGBA',assets:{},skill_icons:{},tree_colors:{}};
function write(name,text){const f=path.join(root,name);fs.mkdirSync(path.dirname(f),{recursive:true});fs.writeFileSync(f,text);}
async function bounds(input,threshold=32){
 const {data,info}=await sharp(input).ensureAlpha().raw().toBuffer({resolveWithObject:true});
 let left=info.width,top=info.height,right=-1,bottom=-1;
 for(let y=0;y<info.height;y++)for(let x=0;x<info.width;x++)if(data[(y*info.width+x)*4+3]>threshold){left=Math.min(left,x);top=Math.min(top,y);right=Math.max(right,x);bottom=Math.max(bottom,y);}
 if(right<0)throw Error('Empty image');
 return {left,top,width:right-left+1,height:bottom-top+1};
}
async function cell(group,i){
 const file=path.join(__dirname,group+'.png'),m=await sharp(file).metadata();
 let x=Math.round(i%3*m.width/3),y=Math.round(Math.floor(i/3)*m.height/2),w=Math.round((i%3+1)*m.width/3)-x,h=Math.round((Math.floor(i/3)+1)*m.height/2)-y;
 // The medical tent extends slightly into the otherwise empty gap next to its cell.
 if(group==='healing'&&i===3)w+=32;
 if(group==='healing'&&i===4){x+=32;w-=32;}
 if(group==='scout'&&i===4){x+=48;w-=48;}
 return sharp(file).extract({left:x,top:y,width:w,height:h}).png().toBuffer();
}
async function save(name,pipeline,notes){
 const file=path.join(root,name+'.webp');fs.mkdirSync(path.dirname(file),{recursive:true});
 await pipeline.webp({lossless:true,effort:6}).toFile(file);
 const m=await sharp(file).metadata(),s=await sharp(file).stats();
 if(!m.hasAlpha||s.channels[3].min!==0||s.channels[3].max<240)throw Error('Invalid alpha '+name);
 manifest.assets[name]={path:'res://assets/ui/skill_tree/'+name+'.webp',width:m.width,height:m.height,notes,sha256:crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex')};
}
async function centered(input,width,height,innerW,innerH,threshold=32){
 const b=await bounds(input,threshold);
 const resized=await sharp(input).extract(b).resize(innerW,innerH,{fit:'contain',background:clear}).png().toBuffer();
 return sharp({create:{width,height,channels:4,background:clear}}).composite([{input:resized,left:Math.floor((width-innerW)/2),top:Math.floor((height-innerH)/2)}]);
}
(async()=>{
 for(const [key,file]of Object.entries(files)){const target=path.join(__dirname,key+'.png');if(!fs.existsSync(target)){if(!generated)throw Error('Missing '+target);fs.copyFileSync(path.join(generated,file),target);}}
 for(const [group,names]of Object.entries(grid))for(let i=0;i<names.length;i++)await save('icons/'+names[i],await centered(await cell(group,i),256,256,208,208), 'Isolated icon; 256 px canvas, <=208 px motif.');
 const states=['locked','available','learned','focus_ring'];
 for(let i=0;i<4;i++)await save('medallions/'+states[i],await centered(await cell('medallions',i),256,256,224,224,128),'256 px aligned canvas; 224 px outer motif; stack at same rect.');
 for(const [i,name]of [[4,'check'],[5,'lock']])await save('status/'+name,await centered(await cell('medallions',i),64,64,56,56),'Separate overlay, never baked into skill icon.');
 const dataDir=path.resolve(root,'../../..','data/skills');
 for(const f of fs.readdirSync(dataDir).filter(x=>x.endsWith('.json')))for(const entry of JSON.parse(fs.readFileSync(path.join(dataDir,f),'utf8'))){
  if(entry.kind==='tree')manifest.tree_colors[entry.id]=entry.color;
  if(entry.kind==='skill'){if(!idMap[entry.id])throw Error('Missing mapping '+entry.id);manifest.skill_icons[entry.id]={name:entry.name,tree:entry.tree,path:manifest.assets['icons/'+idMap[entry.id]].path};}
 }
 if(Object.keys(manifest.skill_icons).length!==21)throw Error('Expected 21 skills');
 manifest.reuse={tooltip:'res://assets/ui/tooltip/manifest.json'};
 write('manifest.json',JSON.stringify(manifest,null,2)+'\n');
 write('skill_icons.json',JSON.stringify(Object.fromEntries(Object.entries(manifest.skill_icons).map(([id,value])=>[id,value.path])),null,2)+'\n');
 console.log('Exported '+Object.keys(manifest.assets).length+' WebP assets; mapped all 21 skill IDs.');
})();

