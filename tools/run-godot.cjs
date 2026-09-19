const { spawn } = require('node:child_process');
const path = require('node:path');
const godot = process.env.GODOT_BIN || 'godot';
const child = spawn(godot, ['--path', path.resolve(__dirname, '..'), ...process.argv.slice(2)], { windowsHide:true, stdio:'inherit' });
child.on('error', error => { console.error(error); process.exitCode=1; });
child.on('exit', code => process.exit(code ?? 1));
const timer=setTimeout(()=>{child.kill(); process.exitCode=124;},180000);
child.on('exit',()=>clearTimeout(timer));
