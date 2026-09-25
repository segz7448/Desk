'use strict';
const crypto=require('crypto'),Database=require('better-sqlite3');const fs=require('fs');
const path=require('path');const dbpath=process.env.DESK_DB_PATH||path.join(process.cwd(),'state','auth.sqlite');fs.mkdirSync(path.dirname(dbpath),{recursive:true,mode:0o700});const db=new Database(dbpath);db.pragma('journal_mode = WAL');db.pragma('foreign_keys = ON');
db.exec(`CREATE TABLE IF NOT EXISTS accounts (id INTEGER PRIMARY KEY CHECK(id=1), login TEXT NOT NULL UNIQUE, salt TEXT NOT NULL, hash TEXT NOT NULL, created_at TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS sessions (token_hash TEXT PRIMARY KEY, account_id INTEGER NOT NULL REFERENCES accounts(id), expires_at INTEGER NOT NULL, created_at INTEGER NOT NULL);
CREATE TABLE IF NOT EXISTS attempts (ip_hash TEXT PRIMARY KEY, tries INTEGER NOT NULL, locked_until INTEGER NOT NULL, last_at INTEGER NOT NULL);`);
const safe=(a,b)=>typeof a==='string'&&typeof b==='string'&&a.length===b.length&&crypto.timingSafeEqual(Buffer.from(a),Buffer.from(b));
const lookup=db.prepare('SELECT id,salt,hash FROM accounts WHERE login=?');
module.exports={
exists:()=>!!lookup.get(process.env.DESK_LOGIN||'desk'),
create:(password)=>{if(db.prepare('SELECT count(*) n FROM accounts').get().n)throw Error('account exists');if(password.length<12||password.length>200)throw Error('password length');const salt=crypto.randomBytes(32).toString('hex'),hash=crypto.scryptSync(password,salt,64).toString('hex');db.prepare('INSERT INTO accounts(id,login,salt,hash,created_at) VALUES (1,?,?,?,?)').run(process.env.DESK_LOGIN||'desk',salt,hash,new Date().toISOString());return true},
check:(login,password)=>{const row=lookup.get(login);if(!row||password.length>200)return false;return safe(crypto.scryptSync(password,row.salt,64).toString('hex'),row.hash)},
newSession:()=>{const token=crypto.randomBytes(32).toString('hex'),now=Date.now();db.prepare('DELETE FROM sessions WHERE expires_at<?').run(now);db.prepare('INSERT INTO sessions(token_hash,account_id,expires_at,created_at) VALUES(?,1,?,?)').run(crypto.createHash('sha256').update(token).digest('hex'),now+3600e3,now);return token},
session:(token)=>{if(!token||!/^[a-f0-9]{64}$/.test(token))return false;return !!db.prepare('SELECT token_hash FROM sessions WHERE token_hash=? AND expires_at>?').get(crypto.createHash('sha256').update(token).digest('hex'),Date.now())},
revoke:(token)=>{if(token)db.prepare('DELETE FROM sessions WHERE token_hash=?').run(crypto.createHash('sha256').update(token).digest('hex'))},
allowed:(ip)=>{const key=crypto.createHash('sha256').update(ip||'unknown').digest('hex'),r=db.prepare('SELECT tries,locked_until FROM attempts WHERE ip_hash=?').get(key);return !r||r.locked_until<=Date.now()},
failed:(ip)=>{const key=crypto.createHash('sha256').update(ip||'unknown').digest('hex'),r=db.prepare('SELECT tries,locked_until FROM attempts WHERE ip_hash=?').get(key);const n=r?.locked_until>Date.now()?r.tries+1:1,until=n>=5?Date.now()+Math.min(30*60e3,30000*Math.pow(2,n-5)):0;db.prepare('INSERT INTO attempts(ip_hash,tries,locked_until,last_at) VALUES(?,?,?,?) ON CONFLICT(ip_hash) DO UPDATE SET tries=excluded.tries,locked_until=excluded.locked_until,last_at=excluded.last_at').run(key,n,until,Date.now())},
clearAttempts:(ip)=>{const key=crypto.createHash('sha256').update(ip||'unknown').digest('hex');db.prepare('DELETE FROM attempts WHERE ip_hash=?').run(key)},
};
