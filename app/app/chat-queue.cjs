'use strict';
// The browser is an unverified input source. Relay authorization is separate
// from the login session, and only the local supervisor holds its bearer key.
const crypto=require('crypto'),fs=require('fs'),path=require('path');
const Database=require('better-sqlite3');
const dbpath=process.env.DESK_DB_PATH||path.join(process.cwd(),'state','auth.sqlite');
const db=new Database(dbpath);db.pragma('journal_mode = WAL');db.pragma('busy_timeout = 5000');
db.exec(`CREATE TABLE IF NOT EXISTS chat_messages (
 id TEXT PRIMARY KEY, role TEXT NOT NULL CHECK(role IN ('web','agent')),
 body TEXT NOT NULL, created_at TEXT NOT NULL, reply_to TEXT,
 delivered_at TEXT, CHECK(length(body) BETWEEN 1 AND 4000));
 CREATE INDEX IF NOT EXISTS chat_pending ON chat_messages(role,delivered_at,created_at);`);
const tokenfile=process.env.DESK_RELAY_TOKEN_FILE||path.join(path.dirname(dbpath),'relay-token');
fs.mkdirSync(path.dirname(tokenfile),{recursive:true,mode:0o700});
if(!fs.existsSync(tokenfile)){try{fs.writeFileSync(tokenfile,crypto.randomBytes(32).toString('hex')+'\n',{mode:0o600,flag:'wx'})}catch(e){if(e.code!=='EEXIST')throw e}}
function secretOK(given){const key=fs.readFileSync(tokenfile,'utf8').trim();return typeof given==='string'&&/^[a-f0-9]{64}$/.test(given)&&crypto.timingSafeEqual(Buffer.from(key),Buffer.from(given))}
function relay(req){return secretOK((req.headers.authorization||'').match(/^Bearer ([a-f0-9]{64})$/)?.[1])}
const record=db.prepare('INSERT INTO chat_messages(id,role,body,created_at,reply_to,delivered_at) VALUES(?,?,?,?,?,?)');
const recent=db.prepare('SELECT id,role,body,created_at,reply_to FROM chat_messages ORDER BY created_at DESC LIMIT 100');
const pending=db.prepare("SELECT id,body,created_at FROM chat_messages WHERE role='web' AND delivered_at IS NULL ORDER BY created_at LIMIT 50");
const mark=db.prepare("UPDATE chat_messages SET delivered_at=? WHERE id=? AND role='web' AND delivered_at IS NULL");
const find=db.prepare("SELECT id,delivered_at FROM chat_messages WHERE id=? AND role='web'");
const respond=db.transaction((id,body,replyId)=>{const original=find.get(replyId);if(!original)throw Error('unknown reply target');if(original.delivered_at)throw Error('already handled');const now=new Date().toISOString();record.run(id,'agent',body,now,replyId,null);mark.run(now,replyId);return {id,role:'agent',body,created_at:now,reply_to:replyId}});
module.exports={relay,secretOK,tokenfile,recent:()=>recent.all().reverse(),pending:()=>pending.all(),submit:(body)=>{const id=crypto.randomUUID(),now=new Date().toISOString();record.run(id,'web',body,now,null,null);return{id,role:'web',body,created_at:now}},respond,mark:(id)=>mark.run(new Date().toISOString(),id).changes};
