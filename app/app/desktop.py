#!/usr/bin/python3
import gi,os,json,time,datetime
from pathlib import Path
gi.require_version('Gtk','3.0')
from gi.repository import Gtk,Gdk,GLib
SOURCE=Path('/home/room/status.json'); LOG=Path('/tmp/observer.log')
CSS=b'''*{font-family:sans-serif}window{background:#101b2e;color:#eef5ff}.desktop{background:#0c1729}.panel{background:#15253b;border:1px solid #3d607e;border-radius:9px}.bar{background:#254461;border-radius:8px 8px 0 0}.title{font-size:15px;font-weight:700;color:#fff}.head{font-size:19px;font-weight:700;color:#fff}.mono{font-family:monospace;font-size:12px;color:#a7dfcb}.small{font-size:12px;color:#b6cde1}.body{font-size:13px;color:#e5f0fa}.metric{font-size:27px;font-weight:700;color:#80ccec}.card{background:#1e3854;border-radius:8px;padding:11px}.tag{color:#8fd7f4;font-size:12px;font-weight:700}textview,textview text{background:#0e2033;color:#9de0ca;font-family:monospace}button{background:#285579;color:white;border:1px solid #4381a5;border-radius:6px;padding:5px 10px}'''
p=Gtk.CssProvider();p.load_from_data(CSS);Gtk.StyleContext.add_provider_for_screen(Gdk.Screen.get_default(),p,Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)
def txt(s,style='body'):
 w=Gtk.Label(label=str(s));w.set_xalign(0);w.set_line_wrap(True);w.get_style_context().add_class(style);return w
def pack(vertical=True,spacing=8):return Gtk.Box(orientation=Gtk.Orientation.VERTICAL if vertical else Gtk.Orientation.HORIZONTAL,spacing=spacing)
def frame(title,w,h,owner):
 outer=Gtk.EventBox();outer.get_style_context().add_class('panel');outer.set_size_request(w,h)
 v=pack();outer.add(v)
 drag=Gtk.EventBox();drag.get_style_context().add_class('bar');drag.add_events(Gdk.EventMask.BUTTON_PRESS_MASK|Gdk.EventMask.BUTTON1_MOTION_MASK|Gdk.EventMask.BUTTON_RELEASE_MASK)
 b=pack(False,8);b.set_margin_start(11);b.set_margin_end(11);b.set_margin_top(8);b.set_margin_bottom(8);drag.add(b);b.pack_start(txt('●  '+title,'title'),True,True,0)
 drag.connect('button-press-event',lambda widget,event:owner.start_drag(event,outer));drag.connect('motion-notify-event',lambda widget,event:owner.drag(event,outer));drag.connect('button-release-event',owner.stop_drag)
 v.pack_start(drag,False,False,0);return outer,v,b
class Desktop(Gtk.Window):
 def __init__(self):
  super().__init__(title='Desk isolated desktop');self.set_decorated(False);self.set_default_size(1280,800);self.set_size_request(1280,800);self.move(0,0)
  self.connect('delete-event',lambda *_:True);self.connect('key-press-event',lambda *_:True)
  self.canvas=Gtk.Fixed();self.canvas.get_style_context().add_class('desktop');self.add(self.canvas);self.drag_state=None;self.started=time.monotonic();self.prev_cpu=(0,self.started)
  top=Gtk.EventBox();top.get_style_context().add_class('bar');top.set_size_request(1280,47);line=pack(False,15);line.set_margin_start(19);line.set_margin_end(19);line.set_margin_top(11);top.add(line);line.pack_start(txt('◆  Desk  /  isolated viewing room','title'),True,True,0);self.clock=txt('','small');line.pack_end(self.clock,False,False,0);self.canvas.put(top,0,0)
  self.dashboard,self.dashboard_inner,head=frame('CONTROL ROOM    •    curated reports',673,665,self);self.canvas.put(self.dashboard,20,66)
  refresh=Gtk.Button(label='Refresh');refresh.connect('clicked',self.update_feed);head.pack_end(refresh,False,False,0)
  self.feedbox=pack();self.feedbox.set_margin_start(15);self.feedbox.set_margin_end(15);self.feedbox.set_margin_top(12)
  scroll=Gtk.ScrolledWindow();scroll.set_policy(Gtk.PolicyType.NEVER,Gtk.PolicyType.AUTOMATIC);scroll.add(self.feedbox);self.dashboard_inner.pack_start(scroll,True,True,0)
  self.terminal,self.terminal_inner,_=frame('FEED OBSERVER    •    isolated process output',557,325,self);self.canvas.put(self.terminal,704,66)
  console=Gtk.ScrolledWindow();console.set_policy(Gtk.PolicyType.NEVER,Gtk.PolicyType.AUTOMATIC);self.terminal_inner.pack_start(console,True,True,0)
  self.log=Gtk.TextView();self.log.set_editable(False);self.log.set_cursor_visible(False);self.log.set_wrap_mode(Gtk.WrapMode.WORD_CHAR);self.log.get_style_context().add_class('mono');self.log.set_left_margin(13);self.log.set_top_margin(12);console.add(self.log)
  self.monitor,self.monitor_inner,_=frame('SYSTEM MONITOR    •    this isolated desktop only',557,330,self);self.canvas.put(self.monitor,704,400)
  self.stats=txt('Loading…','body');self.stats.set_margin_start(15);self.stats.set_margin_top(11);self.monitor_inner.pack_start(self.stats,False,False,0)
  self.processes=txt('','mono');self.processes.set_margin_start(15);self.processes.set_margin_top(13);self.monitor_inner.pack_start(self.processes,False,False,0)
  dock=Gtk.EventBox();dock.get_style_context().add_class('bar');dock.set_size_request(1280,51);d=pack(False,10);d.set_margin_start(16);d.set_margin_top(8);dock.add(d)
  for name,window in [('◈  Reports',self.dashboard),('▣  Observer',self.terminal),('◴  Monitor',self.monitor)]:
   b=Gtk.Button(label=name);b.connect('clicked',self.focus_window,window);d.pack_start(b,False,False,0)
  d.pack_end(txt('Mouse-only display   •   no browser, shell or host access','small'),False,False,16);self.canvas.put(dock,0,746)
  self.update_feed();self.tick();GLib.timeout_add_seconds(2,self.tick);GLib.timeout_add_seconds(60,self.update_feed);self.show_all()
 def focus_window(self,button,window):
  # Raise within the fixed desktop by reordering children. No operating system window manager is exposed.
  window.get_window().raise_()
 def start_drag(self,event,window):
  self.drag_state=(window,event.x_root,event.y_root,*self.canvas.child_get(window,'x','y'));return True
 def drag(self,event,window):
  if self.drag_state and self.drag_state[0] is window:
   _,sx,sy,x,y=self.drag_state;self.canvas.move(window,max(0,min(1280-window.get_allocated_width(),int(x+event.x_root-sx))),max(49,min(742-window.get_allocated_height(),int(y+event.y_root-sy))))
  return True
 def stop_drag(self,*args):self.drag_state=None;return True
 def update_feed(self,*args):
  for child in self.feedbox.get_children():self.feedbox.remove(child)
  try:data=json.loads(SOURCE.read_text())
  except Exception:self.feedbox.pack_start(txt('Feed unavailable. Refresh when ready.'),False,False,0);self.show_all();return True
  self.feedbox.pack_start(txt('Snapshot '+data.get('updated','unknown')+'  •  source-dated reports','small'),False,False,2)
  rev=data['revenue'];card=Gtk.EventBox();card.get_style_context().add_class('card');v=pack();v.set_margin_start(13);v.set_margin_end(13);v.set_margin_top(9);v.set_margin_bottom(9);card.add(v);v.pack_start(txt('REVENUE MISSION','tag'),False,False,0);v.pack_start(txt(rev['settled']+' / '+rev['target'],'metric'),False,False,0);v.pack_start(txt('Dated assistant rollup, not a live payment ledger. '+rev['as_of'],'small'),False,False,0);self.feedbox.pack_start(card,False,False,7)
  self.feedbox.pack_start(txt('COMPANY COMMAND BOARD','head'),False,False,7)
  for company in data.get('companies',[]):
   c=Gtk.EventBox();c.get_style_context().add_class('card');v=pack();v.set_margin_start(12);v.set_margin_end(12);v.set_margin_top(9);v.set_margin_bottom(9);c.add(v);v.pack_start(txt(company['name']+'   /   '+company['ceo'],'title'),False,False,0);v.pack_start(txt(company['work']),False,False,0);v.pack_start(txt('Last report: '+company['last_report'],'small'),False,False,0);self.feedbox.pack_start(c,False,False,4)
  self.feedbox.pack_start(txt('ACQUISITION PIPELINE','head'),False,False,8)
  for a in data.get('acquisition',[]):self.feedbox.pack_start(txt(a['name']+'  •  '+a['value'],'small'),False,False,3)
  self.feedbox.pack_start(txt('WATCHER COVERAGE','head'),False,False,8)
  for w in data.get('watchers',[]):self.feedbox.pack_start(txt(w['name']+'  •  '+w['cadence']+'\n'+w['scope']+'  /  '+w['last_report'],'small'),False,False,5)
  self.feedbox.pack_start(txt('SOURCE-DATED ACTIVITY','head'),False,False,7)
  for a in data.get('activity',[]):self.feedbox.pack_start(txt(a['name']+'  •  '+a['at']+'\n'+a['work'],'small'),False,False,5)
  self.show_all();return True
 def tick(self):
  self.clock.set_text(datetime.datetime.now().strftime('%a %b %-d  •  %I:%M:%S %p')+'   |   Uptime '+str(int(time.monotonic()-self.started))+'s')
  try:
   lines=LOG.read_text().splitlines()[-19:];self.log.get_buffer().set_text('\n'.join(lines))
  except Exception:self.log.get_buffer().set_text('Waiting for isolated observer...')
  found=[];rss=0;cpu_ticks=0
  for entry in Path('/proc').iterdir():
   if not entry.name.isdigit():continue
   try:
    cmd=(entry/'cmdline').read_bytes().replace(b'\x00',b' ').decode(errors='replace')
    stat=(entry/'status').read_text();mem=int(next(x.split()[1] for x in stat.splitlines() if x.startswith('VmRSS:')));raw=(entry/'stat').read_text().split(') ',1)[1].split();ticks=int(raw[11])+int(raw[12])
    if 'desktop.py' in cmd:name='Control room desktop'
    elif 'feed-observer.py' in cmd:name='Feed observer'
    elif 'Xvfb :1 ' in cmd:name='Isolated display server'
    elif 'x11vnc ' in cmd:name='Mouse-only screen relay'
    elif 'socat UNIX-LISTEN:' in cmd:name='Display bridge'
    else:continue
    if name not in [n for n,m in found]:found.append((name,mem));rss+=mem;cpu_ticks+=ticks
   except (OSError,ValueError,StopIteration):pass
  now=time.monotonic();prev_ticks,prev_time=self.prev_cpu;cpu=max(0,(cpu_ticks-prev_ticks)/os.sysconf('SC_CLK_TCK')/max(.01,now-prev_time)*100);self.prev_cpu=(cpu_ticks,now)
  self.stats.set_text('Isolated app CPU: '+str(round(cpu,1))+'%    •    Memory: '+str(round(rss/1024,1))+' MiB\nUptime: '+str(int(now-self.started))+'s    •    '+str(len(found))+' local services running\nProcess list from this namespace only. No host processes shown.')
  self.processes.set_text('\n'.join('●  '+n.ljust(28)+str(round(m/1024,1))+' MiB' for n,m in found))
  return True
Desktop();Gtk.main()
