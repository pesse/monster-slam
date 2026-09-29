const sharp=require('C:/Users/SamuelNitsche/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
sharp('C:/Users/SamuelNitsche/.codex/generated_images/01a0ec42-5682-7e50-ae8e-6506f8be179c/exec-e7f62790-04ef-4ff5-aa12-0674218a0ea1.png').webp({lossless:true}).toFile(__dirname+'/skill-tree-v5.webp');
