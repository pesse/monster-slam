const sharp = require('C:/Users/SamuelNitsche/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
sharp('C:/Users/SamuelNitsche/.codex/generated_images/01a0ec42-5682-7e50-ae8e-6506f8be179c/exec-d5c08306-8fa1-4549-90c8-71242e772d60.png').webp({lossless:true}).toFile(__dirname+'/statistics-v2.webp');
