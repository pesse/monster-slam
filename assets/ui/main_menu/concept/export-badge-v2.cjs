const sharp=require('C:/Users/SamuelNitsche/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
sharp('C:/Users/SamuelNitsche/.codex/generated_images/01a0ec42-5682-7e50-ae8e-6506f8be179c/exec-ccb2cca1-0719-44aa-a950-6bd5007be6b3.png').webp({lossless:true}).toFile(__dirname+'/player-badge-gold-v2.webp');
