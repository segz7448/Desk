#!/usr/bin/env python3
"""Manual, host-side import of one reviewed business artifact to the isolated guest."""
import argparse,os,pathlib,shutil,tempfile
ROOT=pathlib.Path(__file__).resolve().parents[2]
DEST=ROOT/'state/deliverables'
TYPES={'.pdf','.txt','.md','.docx','.xlsx','.csv','.pptx','.png','.jpg'}
p=argparse.ArgumentParser(description='Import one personally reviewed business deliverable')
p.add_argument('file',help='Explicit reviewed artifact, never a broad directory or internal file')
p.add_argument('--name',help='Safe name visible in guest')
a=p.parse_args();src=pathlib.Path(a.file);name=a.name or src.name
if not src.is_file() or src.is_symlink() or src.stat().st_size>20_000_000:raise SystemExit('Invalid source file')
if name!=pathlib.Path(name).name or name.startswith('.') or pathlib.Path(name).suffix.lower() not in TYPES:raise SystemExit('Invalid destination name/type')
DEST.mkdir(parents=True,exist_ok=True,mode=0o700)
fd,tmp=tempfile.mkstemp(prefix='.import-',dir=DEST)
try:
 with os.fdopen(fd,'wb') as out,src.open('rb') as inp:shutil.copyfileobj(inp,out)
 os.chmod(tmp,0o444);os.replace(tmp,DEST/name)
finally:
 if os.path.exists(tmp):os.unlink(tmp)
print('Imported',name)
