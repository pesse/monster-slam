const fs=require('fs'),path=require('path');
const sharp=require('C:/Users/SamuelNitsche/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const root=path.resolve(__dirname,'../..');
const generated='C:/Users/SamuelNitsche/.codex/generated_images/01a0ec42-5682-7e50-ae8e-6506f8be179c/';
(async()=>{
await sharp(generated+'exec-c2840a80-9238-4184-a411-d43801dcca9d.png').webp({lossless:true}).toFile(path.join(root,'statistics/concept/statistics-v3.webp'));
await sharp(generated+'exec-b5e9baec-0864-4297-93f9-0fb6f07c8773.png').webp({lossless:true}).toFile(path.join(root,'skill_tree/concept/skill-tree-v4.webp'));
})();

