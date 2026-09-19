const {spawn} = require('node:child_process');
const path = require('node:path');
const root = path.resolve(__dirname,'..');
const exe = path.join(root,'dist','Weaver-Windows-0.5.0','Weaver.exe');
const p = spawn(exe, ['--resolution','1600x1000','--log-file',path.join(root,'artifacts','release-gpu.log'),'--','--qa','--verify-build','--verify-output='+path.join(root,'artifacts','release')], {cwd:root, windowsHide:true,stdio:'inherit'});
const timeout = setTimeout(()=>{p.kill();process.exitCode=2;},90000);
p.on('error',error=>{clearTimeout(timeout);console.error(error);process.exitCode=1;});
p.on('exit',code=>{clearTimeout(timeout);console.log('RELEASE_EXIT',code);process.exitCode=code??1;});
