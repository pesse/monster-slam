const fs=require('fs'),path=require('path'),sharp=require(process.env.SHARP_MODULE||'sharp');
const root=path.resolve(__dirname,'..');
(async()=>{
const src=path.join(__dirname,'frame.png');
await sharp(src).webp({lossless:true}).toFile(path.join(root,'frame.webp'));
await sharp(src).extract({left:1010,top:650,width:250,height:200}).webp({lossless:true}).toFile(path.join(root,'level_overlay.webp'));
const stats=await sharp(src).stats();if(stats.channels[3].min!==0)throw Error('Missing transparent background');
await sharp(src).flatten({background:'#172131'}).resize(768,512).png().toFile(path.join(root,'preview/frame.png'));
console.log('RGBA frame and aligned level overlay exported');
})();
