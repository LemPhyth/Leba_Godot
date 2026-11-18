"""Build AS2 observation probes and explicitly selected controlled fixtures.

Original tags/scripts are retained. An extra frame-1 DoAction creates an empty
observer clip and trace listener. Without --fixture it does not drive gameplay.
Fixtures explicitly change clip frames, scenario state and labelled boundaries.
Ruffle measurements remain emulator + instrumentation evidence, not native Flash.
"""
from pathlib import Path
import hashlib
import json
import os
import subprocess
import argparse
import re

WORKSPACE = Path(__file__).resolve().parents[2]
SOURCE = WORKSPACE / 'leba/雷巴的冒险EX.swf'
DEST = WORKSPACE / 'tools/swf/runtime_probe/leiba02'
FFDEC = WORKSPACE / 'tools/swf/vendor/ffdec'
PROJECT_PROBES = Path(__file__).resolve().parent/'probes'

OBSERVER = r'''
var leibaObserver = _root.createEmptyMovieClip("__leiba02_observer",1048500);
leibaObserver.tick = 0;
leibaObserver.onEnterFrame = function() {
    this.tick++;
    if(this.tick < 50000) {
        trace("LEIBA02|t="+this.tick+"|root="+_root._currentframe+"|crt="+_root.crt+"|nan="+_root.nan+"|px="+_root.일._x+"|py="+_root.일._y+"|actor="+_root.일._currentframe+"|action="+_root.일.동작._currentframe+"|hp="+_root.hp+"|mp="+_root.mp+"|ex="+_root.적._x+"|ey="+_root.적._y+"|ehp="+_root.적.hp+"|enemy="+_root.적.속._currentframe+"|mobsp="+_root.적.mobsp+"|gravity="+_root.적.중력+"|hit="+_root.적.공중.타격._currentframe+"|dialog="+_root.대화창._currentframe);
        trace("LEIBA02_DETAIL|t="+this.tick+"|hurt="+_root.일.맞는중._currentframe+"|outer="+_root.적._currentframe+"|air="+_root.적.공중._currentframe+"|gacc="+_root.적.중력가속도+"|ehp2="+_root.적2.hp+"|enemy2="+_root.적2.속._currentframe+"|ehp3="+_root.적3.hp+"|ehp4="+_root.적4.hp);
        if(_root.일.몸빵 != undefined && _root.적.속.몬공 != undefined) {
            trace("LEIBA_CONTACT|t="+this.tick+"|overlap="+_root.일.몸빵.hitTest(_root.적.속.몬공)+"|body_xmin="+_root.일.몸빵.getBounds(_root).xMin+"|body_xmax="+_root.일.몸빵.getBounds(_root).xMax+"|attack_xmin="+_root.적.속.몬공.getBounds(_root).xMin+"|attack_xmax="+_root.적.속.몬공.getBounds(_root).xMax);
        }
    }
};
var leibaKeys = new Object();
leibaKeys.onKeyDown = function() { trace("LEIBA02_KEY|code="+Key.getCode()); };
Key.addListener(leibaKeys);
'''

# Controlled fixtures call original clip methods; they do not replace original scripts.
# They are intentionally NOT described as natural keyboard gameplay evidence.
ACTION_FIXTURE = r'''
leibaObserver.fixture = function(t) {
    if(t == 30) { _root.crt=0; _root.nan=0; _root.gotoAndStop(2); }
    if(t == 40) { _root.대화창.gotoAndStop(9); _root.일.gotoAndStop(1); }
    var target = 0;
    if(t == 60) target=7;
    if(t == 100) target=11;
    if(t == 140) target=13;
    if(t == 180) target=8;
    if(t == 220) target=9;
    if(t == 260) target=16;
    if(t == 300) target=10;
    if(t == 340) target=14;
    if(t == 342) target=14;
    if(target > 0) {
        _root.일.gotoAndStop(target);
        trace("LEIBA_FIXTURE|t="+t+"|goto="+target+"|actor="+_root.일._currentframe+"|action="+_root.일.동작._currentframe+"|hurt="+_root.일.맞는중._currentframe+"|hp="+_root.hp);
    }
    if(t == 348) {
        _root.일.맞는중.gotoAndPlay(2);
        trace("LEIBA_FIXTURE|t="+t+"|seek_hurt=2|hurt="+_root.일.맞는중._currentframe+"|hp="+_root.hp);
    }
    if(t == 380) { _root.crt=1; _root.gotoAndStop(2); }
    if(t == 390) { _root.대화창.gotoAndStop(9); _root.일.gotoAndStop(30); }
    if(t == 410) _root.일.gotoAndStop(37);
    if(t == 450) _root.일.gotoAndStop(42);
    if(t == 490) _root.일.gotoAndStop(44);
    if(t == 530) { trace("LEIBA_FIXTURE_DONE"); this.fixture=undefined; }
};
'''

HIT_FIXTURE = r'''
leibaObserver.fixture = function(t) {
    if(t == 30) { _root.crt=0; _root.nan=0; _root.gotoAndStop(4); }
    if(t >= 35 && t < 155) {
        _root.일._x=40; _root.적._x=550; _root.적2._x=550; _root.적3._x=550; _root.적4._x=550;
    }
    if(t == 40) { _root.대화창.gotoAndStop(9); _root.일.gotoAndStop(1); }
    if(t == 60 || t == 62 || t == 105) {
        _root.일.gotoAndStop(14);
        trace("LEIBA_HIT_FIXTURE|t="+t+"|parent=14|hurt="+_root.일.맞는중._currentframe+"|hp="+_root.hp);
    }
    if(t == 68) _root.일.맞는중.gotoAndPlay(2);
    if(t == 85) { _root.적.hp=0; trace("LEIBA_HIT_FIXTURE|t="+t+"|kill_first_root4=1"); }
    if(t == 155) { _root.gotoAndStop(6); }
    if(t >= 160 && t < 220) { _root.일._x=40; _root.적._x=550; }
    if(t == 165) { _root.대화창.gotoAndStop(9); _root.일.gotoAndStop(1); }
    if(t == 180) _root.일.gotoAndStop(14);
    if(t >= 180 && t <= 182) {
        _root.일.맞는중.gotoAndPlay(2);
        trace("LEIBA_HIT_FIXTURE|t="+t+"|seek_hurt=2|hp="+_root.hp);
    }
    if(t == 220) { trace("LEIBA_FIXTURE_DONE"); this.fixture=undefined; }
};
'''

CONTACT_FIXTURE = r'''
leibaObserver.fixture = function(t) {
    if(t == 30) { _root.crt=0; _root.nan=0; _root.gotoAndStop(6); }
    if(t == 40) _root.일.gotoAndStop(1);
    if(t >= 55 && t <= 65) { _root.일._x=300; _root.적._x=400; }
    if(t == 60) { _root.적.속.gotoAndPlay(68); trace("LEIBA_CONTACT_FIXTURE|t=60|attack=7176_68"); }
    if(t == 66) _root.일._x=40;
    if(t == 100) { _root.gotoAndStop(2); }
    if(t == 110) { _root.대화창.gotoAndStop(9); _root.일.gotoAndStop(1); }
    if(t >= 135 && t <= 146) { _root.일._x=390; _root.적._x=400; }
    if(t == 140) { _root.적.속.gotoAndPlay(26); trace("LEIBA_CONTACT_FIXTURE|t=140|attack=4030_26"); }
    if(t == 147) _root.일._x=40;
    if(t == 180) { trace("LEIBA_FIXTURE_DONE"); this.fixture=undefined; }
};
'''

M1_FIXTURE = r'''
leibaObserver.realIsDown = Key.isDown;
leibaObserver.held = {};
Key.isDown = function(code) { return _root.__leiba02_observer.held[code] == true; };
leibaObserver.fixture = function(t) {
    this.held = {};
    if(t == 30) { _root.crt=0; _root.nan=0; _root.gotoAndStop(2); }
    if(t == 40) { _root.대화창.gotoAndStop(9); _root.일.gotoAndStop(1); }
    if(t >= 50 && t < 60 || t >= 125 && t < 145) this.held[39]=true;
    if(t >= 55 && t < 65) this.held[37]=true;
    if(t >= 170 && t < 205 || t >= 230 && t < 250) this.held[88]=true;
    if(t >= 235 && t < 250) this.held[37]=true;
    if(t == 80 || t == 125 || t == 170 || t == 215) _root.일.gotoAndStop(95);
    if(t == 260) _root.일.gotoAndStop(12);
    if(t == 290) { _root.일._xscale=-Math.abs(_root.일._xscale); _root.bug1=-1; _root.일.gotoAndStop(12); }
    if(t == 320) { _root.일._xscale=Math.abs(_root.일._xscale); _root.bug1=1; _root.일.gotoAndStop(5); }
    if(t == 355) _root.일.gotoAndStop(6);
    if(t >= 30 && t < 390) {
        trace("LEBA_M1|t="+t+"|parent="+_root.일._currentframe+"|child="+_root.일.동작._currentframe+"|sub="+_root.일.동작.점프중._currentframe+"|sub_y="+_root.일.동작.점프중._y+"|cx="+_root.일.동작._x+"|cy="+_root.일.동작._y+"|move="+_root.일.이동._currentframe+"|px="+_root.일._x+"|face="+_root.bug1+"|body="+_root.일.몸빵._currentframe+"|body_xmin="+_root.일.몸빵.getBounds(_root).xMin+"|body_xmax="+_root.일.몸빵.getBounds(_root).xMax+"|flyInt="+_root.flyInt);
        var shots="";
        for(var n in _root.일) {
            if(n.indexOf("대각총알") == 0) shots+=n+":"+_root.일[n]._currentframe+":"+_root.일[n]._x+":"+_root.일[n]._y+",";
        }
        if(shots != "") trace("LEBA_M1_SHOTS|t="+t+"|shots="+shots);
    }
    if(t == 390) { Key.isDown=this.realIsDown; trace("LEIBA_FIXTURE_DONE"); this.fixture=undefined; }
};
'''

M1_NATIVE = r'''
leibaKeys.onKeyDown = function() {
    var code=Key.getCode();
    trace("LEIBA02_KEY|code="+code);
    if(code == 113) _root.일.gotoAndStop(2);
    if(code == 114) { _root.일.gotoAndStop(14); _root.일.맞는중.gotoAndStop(1); }
    if(code == 115) { _root.__leiba02_observer.mpLock=2; _root.mp=2; }
    if(code == 116) { _root.__leiba02_observer.mpLock=undefined; _root.mp=100; _root.스킬창.잭스파이크.gotoAndStop(1); }
    if(code == 117) _root.스킬창.잭스파이크.gotoAndStop(2);
    if(code == 118) _root.일.gotoAndStop(1);
    if(code >= 113 && code <= 118) trace("LEBA_M1_PREP|code="+code+"|t="+_root.__leiba02_observer.tick+"|parent="+_root.일._currentframe+"|mp="+_root.mp+"|zc="+_root.스킬창.잭스파이크._currentframe);
};
leibaObserver.fixture = function(t) {
    if(t == 30) { _root.crt=0; _root.nan=0; _root.gotoAndStop(2); }
    if(t == 40) { _root.대화창.gotoAndStop(9); _root.일.gotoAndStop(1); }
    if(this.mpLock != undefined) _root.mp=this.mpLock;
    if(t >= 30) {
        trace("LEBA_M1_NATIVE|t="+t+"|ms="+getTimer()+"|parent="+_root.일._currentframe+"|child="+_root.일.동작._currentframe+"|sub="+_root.일.동작.점프중._currentframe+"|sub_y="+_root.일.동작.점프중._y+"|cx="+_root.일.동작._x+"|move="+_root.일.이동._currentframe+"|px="+_root.일._x+"|face="+_root.bug1+"|body="+_root.일.몸빵._currentframe+"|zc="+_root.스킬창.잭스파이크._currentframe+"|mp="+_root.mp);
        var shots="";
        for(var n in _root.일) {
            if(n.indexOf("대각총알") == 0) shots+=n+":"+_root.일[n]._currentframe+":"+_root.일[n]._x+":"+_root.일[n]._y+",";
        }
        if(shots != "") trace("LEBA_M1_SHOTS|t="+t+"|shots="+shots);
    }
};
'''

JAVA = r'''
import java.io.*;
import java.nio.file.*;
import com.jpexs.decompiler.flash.SWF;
import com.jpexs.decompiler.flash.tags.*;
import com.jpexs.decompiler.flash.action.parser.script.ActionScript2Parser;
class AddObserver {
 public static void main(String[] args) throws Exception {
  SWF swf = new SWF(new FileInputStream(args[0]),false);
  DoActionTag observer = new DoActionTag(swf);
  observer.setActions(new ActionScript2Parser(swf,observer).actionsFromString(Files.readString(Path.of(args[1])),swf.getCharset()));
  int i=0;for(Tag t:swf.getTags()) { if(t instanceof ShowFrameTag)break;i++; }
  swf.addTag(i,observer);
  swf.saveTo(new FileOutputStream(args[2]));
  System.out.println("Added one observation tag before root ShowFrame1; original scripts retained.");
 }
}
'''

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    global DEST
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--name',default='leiba02_20261112',help='New derived probe directory, not original game data')
    parser.add_argument('--fixture',choices=['action-timing','hit-observers','enemy-contact','m1-basics','m1-native','m1-z-timers','m1-held','m1-held-native','act02-defaults','act02-summons','act02-persistent','act02-status','act02-v','act02-y-full'],help='Controlled original-clip calls; NOT natural keyboard evidence')
    parser.add_argument('--nan',type=int,choices=range(3),default=0,help='Controlled fixture difficulty; unused by observation-only probe')
    args = parser.parse_args()
    if not re.fullmatch(r'[a-zA-Z0-9_\-]+',args.name):
        raise ValueError('Probe name must be a simple directory identifier')
    DEST = WORKSPACE/'tools/swf/runtime_probe'/args.name
    if (DEST/'observed.swf').exists():
        raise FileExistsError('Preserve existing probe provenance/logs; use a new --name')
    before = digest(SOURCE)
    if before != 'afef4c43153780e9140eca7234b5af26c4a751596efefeb071d35428435a909d':
        raise ValueError('Source SWF differs from investigated baseline')
    DEST.mkdir(parents=True, exist_ok=True)
    observer = OBSERVER
    if args.fixture:
        fixtures = {'action-timing':ACTION_FIXTURE,'hit-observers':HIT_FIXTURE,'enemy-contact':CONTACT_FIXTURE,'m1-basics':M1_FIXTURE,'m1-native':M1_NATIVE,
                    'm1-z-timers':(PROJECT_PROBES/'m1_z_timers.as').read_text(encoding='utf8') if args.fixture == 'm1-z-timers' else '',
                    'm1-held':(PROJECT_PROBES/'m1_held_input.as').read_text(encoding='utf8') if args.fixture == 'm1-held' else '',
                    'm1-held-native':(PROJECT_PROBES/'m1_held_native.as').read_text(encoding='utf8') if args.fixture == 'm1-held-native' else '',
                    'act02-defaults':(PROJECT_PROBES/'act02_defaults.as').read_text(encoding='utf8') if args.fixture == 'act02-defaults' else '',
                    'act02-summons':(PROJECT_PROBES/'act02_summons.as').read_text(encoding='utf8') if args.fixture == 'act02-summons' else '',
                    'act02-persistent':(PROJECT_PROBES/'act02_persistent.as').read_text(encoding='utf8') if args.fixture == 'act02-persistent' else '',
                    'act02-status':(PROJECT_PROBES/'act02_status.as').read_text(encoding='utf8') if args.fixture == 'act02-status' else '',
                    'act02-v':(PROJECT_PROBES/'act02_v.as').read_text(encoding='utf8') if args.fixture == 'act02-v' else '',
                    'act02-y-full':(PROJECT_PROBES/'act02_y_full.as').read_text(encoding='utf8') if args.fixture == 'act02-y-full' else ''}
        fixture = fixtures[args.fixture].replace('_root.nan=0','_root.nan=%d' % args.nan)
        observer = observer.replace('    this.tick++;','    this.tick++;\n    if(this.fixture != undefined) this.fixture(this.tick);') + fixture
    (DEST/'observer.as').write_text(observer,encoding='utf8')
    (DEST/'AddObserver.java').write_text(JAVA,encoding='utf8')
    out=DEST/'observed.swf'
    subprocess.run(['java','-Xmx2g','-Djava.awt.headless=true','-cp',str(FFDEC/'ffdec.jar')+os.pathsep+str(FFDEC/'lib/*'),str(DEST/'AddObserver.java'),str(SOURCE),str(DEST/'observer.as'),str(out)],check=True)
    if before != digest(SOURCE):
        raise RuntimeError('Source changed')
    fixture_changes = {
        'act02-y-full':['controlled original parent24 and parent25 actor entry with crt0/nan0/lightning8/200 setup; MP/cubes/slot not written','two enemy hp2000/position/ground baselines; one player position and parent2 seed to exercise original walking','no manufactured marker/bullet/damage/summon/timer outcome; original natural292/81/exit clocks retained'],
        'act02-v':['controlled training entry and enemy hp2000/positions','seek original player parent98 twice for successful and empty grab; no fake zab/pren/result writes','trace source anchors and target states; original scripts retained'],
        'action-timing':['crt/nan','root goto','player parent goto and hurt child seek'],
        'hit-observers':['crt/nan','root/dialogue/player goto','player and enemy X positions','first root4 enemy hp=0','hurt child seek'],
        'enemy-contact':['crt/nan','root/dialogue/player goto','player and enemy X positions','enemy inner attack goto'],
        'm1-basics':['crt/nan/root/dialogue','player parent goto and facing','Key.isDown overridden with source-tick held-state fixture; no real keyboard events'],
        'm1-native':['crt/nan/root/dialogue startup shortcut','F2/F3 parent prep, F4 MP2 hold, F5 MP100/CD reset, F6 CD2 hold, F7 idle prep; Z/C/X events remain host inputs'],
        'm1-z-timers':['root/parent/positions/facing/air gravity fixtures','delegating wrappers around original interval/timeout/clear calls'],
        'm1-held':['root Key shadow object with explicit held flags','root/parent/facing/position setup; original global Key untouched'],
        'm1-held-native':['temporarily clear isDown READ_ONLY4 and supply explicit controlled held flags on original Key object','root/parent/positions/facing; original function and property flag restored at300'],
        'act02-status':['controlled H source flight and explicitly frozen baseline','source1474 attachments near target rather than X input; HP2000/positions explicit','Q silver timer and original T reticle seek; no original Key/random/skillscript replacement'],
        'act02-persistent':['controlled Q choices, R, three C4 placements and detonation, one Y action','enemy HP2000 and explicit positions; random731 attached directly at enemy rather than bullet entry','original Key, Math.random, skill scripts and independent timers untouched'],
        'act02-summons':['controlled training entry with selected defaults','explicit enemy hp2000 for observing small changes; A contact and150timeout, W contact fixture','position locks and deletion only of tracked fixture summons; no original scripts/setters replaced'],
        'act02-defaults':['crt0 selection shortcut with explicit lightning8/200, root40 to original41','temporary original Key.isDown property flag probe, no keyDown generated','F load direct parent114, explicit original HUD throw entry effects','8495 HP/MP200 and skillbar7 replay idle and during D; not OS button input'],
    }
    record={'source':str(SOURCE),'source_sha256':before,'derived':str(out),'derived_sha256':digest(out),
            'observer_sha256':digest(DEST/'observer.as'),'mutation':'One new root-frame1 DoAction; no original script replacement',
            'fixture':args.fixture,
            'fixture_changes':fixture_changes.get(args.fixture,[]),
            'fixture_nan':args.nan if args.fixture else None,
            'limitations':['Ruffle is not Adobe Flash','Additional listener and trace work can affect scheduling/elapsed real time',
                          'Controlled fixture changes the listed scenario state; not natural keyboard evidence' if args.fixture else 'No gameplay variables or inputs set by observer']}
    (DEST/'provenance.json').write_text(json.dumps(record,ensure_ascii=False,indent=2),encoding='utf8')
    print(out)

if __name__=='__main__': main()
