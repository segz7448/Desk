#!/usr/bin/python3
import json,time,datetime,os
from pathlib import Path
source=Path('/home/room/status.json')
last=None
print('[isolated observer] Starting. Source: curated read-only status feed.',flush=True)
while True:
 try:
  data=json.loads(source.read_text())
  stamp=data.get('updated','unknown snapshot')
  if stamp!=last:
   print(datetime.datetime.now().strftime('%H:%M:%S')+'  feed.refresh  snapshot='+stamp,flush=True)
   for item in data.get('companies',[]):
    print('  '+item['name']+'  latest report: '+item.get('last_report','unknown'),flush=True)
   print('  watchers: '+str(len(data.get('watchers',[])))+'   feed: ready',flush=True)
   last=stamp
  else:
   print(datetime.datetime.now().strftime('%H:%M:%S')+'  feed.check    no new snapshot; viewer healthy',flush=True)
 except Exception as e:print(datetime.datetime.now().strftime('%H:%M:%S')+'  feed.check    unavailable ('+type(e).__name__+')',flush=True)
 time.sleep(15)
