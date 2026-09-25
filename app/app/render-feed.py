#!/usr/bin/python3
"""Validate a curated input JSON and atomically update the isolated display feed."""
import json,os,pathlib,sys,tempfile,datetime
if len(sys.argv)!=3:raise SystemExit('usage: render-feed.py INPUT.json OUTPUT.json')
source=pathlib.Path(sys.argv[1]);dest=pathlib.Path(sys.argv[2]);payload=json.loads(source.read_text())
required={'updated':str,'companies':list,'watchers':list,'revenue':dict,'acquisition':list,'activity':list}
for key,typ in required.items():
 if not isinstance(payload.get(key),typ):raise ValueError('missing or invalid field: '+key)
for collection in ('companies','watchers','acquisition','activity'):
 if len(payload[collection])>30:raise ValueError('too many '+collection)
for entry in payload['companies']:
 for key in ('name','ceo','work','last_report'):
  if not isinstance(entry.get(key),str):raise ValueError('company missing '+key)
# Input must already be approved for disclosure. Do not put raw logs, credentials, or private paths here.
dest.parent.mkdir(parents=True,exist_ok=True)
fd,tmp=tempfile.mkstemp(prefix='.feed-',dir=dest.parent)
try:
 with os.fdopen(fd,'w') as f:json.dump(payload,f,ensure_ascii=False);f.flush();os.fsync(f.fileno())
 os.chmod(tmp,0o644);os.replace(tmp,dest)
finally:
 if os.path.exists(tmp):os.unlink(tmp)
print('Curated feed updated at',datetime.datetime.now(datetime.timezone.utc).isoformat())
