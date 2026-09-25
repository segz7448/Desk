'use strict';
const fs=require('fs'),path=require('path');
const dbpath=process.env.DESK_DB_PATH||path.join(process.cwd(),'state','auth.sqlite');
fs.mkdirSync(path.dirname(dbpath),{recursive:true,mode:0o700});
const auth=require('./auth.cjs');
if(auth.exists())throw Error('Account already initialized');
if(process.stdin.isTTY)throw Error('Pipe a password through stdin; do not put it in a command argument');
let input='';process.stdin.setEncoding('utf8');process.stdin.on('data',c=>input+=c);process.stdin.on('end',()=>{auth.create(input.trimEnd());console.log('Login initialized');});
