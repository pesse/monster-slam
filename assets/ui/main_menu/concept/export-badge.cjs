const sharp=require('C:/Users/SamuelNitsche/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
sharp('C:/Users/SamuelNitsche/.codex/generated_images/01a0ec42-5682-7e50-ae8e-6506f8be179c/exec-0d3e0aa2-33a5-4046-8254-ecbade66a5c9.png').webp({lossless:true}).toFile(__dirname+'/player-badge-gold.webp');
