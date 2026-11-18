// ACT02 persistent effects: append after OBSERVER; builder key act02-persistent.
// Controlled original clips, NOT natural input. No original AS, Math.random,
// Key, clocks, property setters or timer functions are replaced.
// Isolated Ruffle: Hidden, volume0, memory storage, independent config/cache.
//
// Interventions (also EVENT traces):
// 30 selection values crt0/nan0/lightning8/200 and root.play40.
// 40 player132.4/314.9/right, enemy520/361 ground/idle/g0/gacc0/hp=hpm2000.
// 50 actor18;60 only if actual Q action12, action.play13 fire choice.
// 90 actor18;100 only if actual Q action12, action.play22 silver choice.
// No timer seek, no flag substitution: original timers must run all355frames.
// 130 actor23 R. Original action25 attaches1513; no floor seek or restart.
// 355 reset positions/HP/gravity; enemy175; c4=0 and enemy C4container.stop1.
// 360/380/400 actor21, original4777 collision attaches bombs; no container++.
// 420 actor22 detonation (bypasses input/cost), original4779 owns f5/f12/f20.
// 460..668 every16ticks, stop spawning once BOTH original731 paths observed:
// remove only prior fixture fire clip, reseed enemy250/hp2000/ground, attach
// original symbol731 "익스플로젼" at that enemy's root position. This bypasses
// projectile creation/collision; Math.random and the symbol's source scripts
// remain original. At most14 attempts; missing branch is a reported failure.
// Reserved AS depth1047000 is below observer1048500, above original static
// actors, explicitly chosen to avoid overwriting normal source attach slots.
// 685 remove only the tracked fixture fire clip; enemy250/hp2000/ground.
// 690 actor24 Y, observe one original root4491 entry and bullet hosts; no
// rewrite of the suspected root/child coordinate mismatch. This limited
// Y window is observation, not complete summon/focus/damage acceptance.
// 780 DONE. All pending original loops/flags are observed, never fast-forwarded.
//
// STATE once/tick30..780 plus immediate labels: root/actor/action, enemyHP,
// physical states, timer frames/flags, R1513/R1503/R1502 frames and observed
// object serials, C4 container/count, Y root/normal/focus/timer frames.
// C4 rows include each original bomb, flash child and1140 helper frame/bounds.
// FIRE rows give source731 frames, first random branch,224 helper/hitTests.
// Y_UNIT rows identify four normal children; Y_BULLET records local/root-space
// points, actual parent, AS depth and frame for named bullets at original
// potential hosts. No recursively dumping unrelated display trees.
// READONLY observations precede remaining queued source callbacks; sampled
// frame numbers are not a claim of a complete intra-tick instruction trace.

leibaObserver.pCase="boot";
leibaObserver.pFailures=0;
leibaObserver.pKey=_global.Key;
leibaObserver.pIsDown=_global.Key.isDown;
leibaObserver.pRClip=undefined;
leibaObserver.pRLeaf=undefined;
leibaObserver.pRSerial=0;
leibaObserver.pRLeafSerial=0;
leibaObserver.pRFrames=0;
leibaObserver.pRLoops=0;
leibaObserver.pRPrevFrame=undefined;
leibaObserver.pFireClip=undefined;
leibaObserver.pFireAttempts=0;
leibaObserver.pSeenBranch3=false;
leibaObserver.pSeenBranch27=false;
leibaObserver.pFireBranch=undefined;
leibaObserver.pFireOn=undefined;
leibaObserver.pFireOff=undefined;
leibaObserver.pSilverOn=undefined;
leibaObserver.pSilverOff=undefined;
leibaObserver.pYEntered=false;
leibaObserver.pYBulletRows=0;

leibaObserver.pCheck=function(name,ok) {
    if(!ok)this.pFailures++;
    trace("ACT02_PERSIST_CHECK|t="+this.tick+"|case="+this.pCase+"|name="+name+"|ok="+ok+"|failures="+this.pFailures);
    return ok;
};
leibaObserver.pEvent=function(event,mode) {
    trace("ACT02_PERSIST_EVENT|t="+this.tick+"|ms="+getTimer()+"|case="+this.pCase+"|event="+event+"|mode="+mode+"|actor="+_root.일._currentframe+"|action="+_root.일.동작._currentframe);
};
leibaObserver.pAt=function(owner,depth) {
    if(typeof(owner)!="movieclip")return undefined;
    return owner.getInstanceAtDepth(depth);
};
leibaObserver.pHit=function(a,b) {
    if(typeof(a)!="movieclip"||typeof(b)!="movieclip")return undefined;
    return a.hitTest(b);
};
leibaObserver.pSeed=function(ex) {
    _root.일.gotoAndStop(1);
    _root.일._x=132.4;_root.일._y=314.9;
    _root.일._xscale=Math.abs(_root.일._xscale);_root.bug1=1;
    _root.적._x=ex;_root.적._y=361;
    _root.적.hp=2000;_root.적.hpm=2000;
    _root.적.중력=0;_root.적.중력가속도=0;
    _root.적.gotoAndStop(1);_root.적.속.gotoAndStop(1);
    this.pEvent("seed_positions_facing_enemy2000_ground_gravity0","fixture_not_original_training_hp");
};
leibaObserver.pEnter=function(parent,label) {
    this.pSample("before_"+label);
    if(!this.pCheck(label+"_actor_idle",_root.일._currentframe==1))return;
    _root.일.gotoAndPlay(parent);
    this.pEvent(label,"direct_parent_seek_input_MP_CD_bypassed");
    this.pSample("after_"+label);
};
leibaObserver.pBomb=function(clip,name,tag) {
    if(typeof(clip)!="movieclip")return;
    var hit=this.pAt(clip,-16359);
    var bounds=hit.getBounds(_root);
    trace("ACT02_PERSIST_C4|t="+this.tick+"|ms="+getTimer()+"|case="+this.pCase+"|tag="+tag+"|name="+name+"|path="+clip+"|parent="+clip._parent+"|depth="+clip.getDepth()+"|frame="+clip._currentframe+"|flash="+clip.속._currentframe+"|hit="+hit._currentframe+"|normal="+this.pHit(_root.적.속.행동몸빵,hit)+"|air="+this.pHit(_root.적.공중,hit)+"|xmin="+bounds.xMin+"|xmax="+bounds.xMax+"|ymin="+bounds.yMin+"|ymax="+bounds.yMax);
};
leibaObserver.pFireSample=function(tag) {
    var c=this.pFireClip;
    if(typeof(c)!="movieclip"||c._parent!=_root)return;
    var f=c._currentframe;
    if(this.pFireBranch==undefined) {
        if(f>=3&&f<=10){this.pFireBranch=3;this.pSeenBranch3=true;}
        if(f>=27&&f<=34){this.pFireBranch=27;this.pSeenBranch27=true;}
    }
    var hit=this.pAt(c,-16369);
    var b=hit.getBounds(_root);
    trace("ACT02_PERSIST_FIRE|t="+this.tick+"|ms="+getTimer()+"|case="+this.pCase+"|tag="+tag+"|attempt="+this.pFireAttempts+"|path="+c+"|name="+c._name+"|parent="+c._parent+"|depth="+c.getDepth()+"|frame="+f+"|branch="+this.pFireBranch+"|x="+c._x+"|y="+c._y+"|hit="+hit._currentframe+"|normal="+this.pHit(_root.적.속.행동몸빵,hit)+"|air="+this.pHit(_root.적.공중,hit)+"|xmin="+b.xMin+"|xmax="+b.xMax+"|ymin="+b.yMin+"|ymax="+b.yMax);
};
leibaObserver.pBullets=function(owner,ownerLabel,tag) {
    if(typeof(owner)!="movieclip")return;
    for(var key in owner) {
        var b=owner[key];
        if(key.indexOf("총알")==0&&typeof(b)=="movieclip"&&b._parent==owner) {
            var pt={x:0,y:0};b.localToGlobal(pt);_root.globalToLocal(pt);
            trace("ACT02_PERSIST_Y_BULLET|t="+this.tick+"|ms="+getTimer()+"|tag="+tag+"|host_label="+ownerLabel+"|owner="+owner+"|key="+key+"|path="+b+"|parent="+b._parent+"|depth="+b.getDepth()+"|frame="+b._currentframe+"|x="+b._x+"|y="+b._y+"|root_x="+pt.x+"|root_y="+pt.y+"|root_lookup_same="+(_root[key]==b));
            this.pYBulletRows++;
        }
    }
};
leibaObserver.pYUnit=function(owner,depth,id,tag) {
    var u=this.pAt(owner,depth);
    if(typeof(u)!="movieclip")return;
    var pt={x:0,y:0};u.localToGlobal(pt);_root.globalToLocal(pt);
    trace("ACT02_PERSIST_Y_UNIT|t="+this.tick+"|ms="+getTimer()+"|tag="+tag+"|source_id="+id+"|path="+u+"|parent="+u._parent+"|depth="+u.getDepth()+"|frame="+u._currentframe+"|total="+u._totalframes+"|i="+u.i+"|x="+u._x+"|y="+u._y+"|root_x="+pt.x+"|root_y="+pt.y);
    this.pBullets(u,"unit"+id,tag);
};
leibaObserver.pSample=function(tag) {
    var actor=_root.일;var e=_root.적;
    var floor=_root.불장판;
    var r=this.pAt(floor,-16383);
    if(r._totalframes!=60)r=undefined;
    var leaf=this.pAt(r,-16383);
    if(leaf._totalframes!=25)leaf=undefined;
    if(r!=undefined&&r!=this.pRClip){this.pRClip=r;this.pRSerial++;this.pRPrevFrame=undefined;}
    if(leaf!=undefined&&leaf!=this.pRLeaf){this.pRLeaf=leaf;this.pRLeafSerial++;}
    if(tag=="tick"&&r!=undefined) {
        this.pRFrames++;
        if(this.pRPrevFrame>r._currentframe)this.pRLoops++;
        this.pRPrevFrame=r._currentframe;
    }
    if(this.pFireOn==undefined&&_root.zak==1)this.pFireOn=this.tick;
    if(this.pFireOn!=undefined&&this.pFireOff==undefined&&_root.zak==0)this.pFireOff=this.tick;
    if(this.pSilverOn==undefined&&_root.eun==1)this.pSilverOn=this.tick;
    if(this.pSilverOn!=undefined&&this.pSilverOff==undefined&&_root.eun==0)this.pSilverOff=this.tick;
    var y=_root.여거너;
    if(this.tick>=690&&y._currentframe==2)this.pYEntered=true;
    trace("ACT02_PERSIST_STATE|t="+this.tick+"|ms="+getTimer()+"|case="+this.pCase+"|phase=observer_before_remaining_callbacks|tag="+tag+"|root="+_root._currentframe+"|root_x="+_root._x+"|root_y="+_root._y+"|actor="+actor._currentframe+"|action="+actor.동작._currentframe+"|px="+actor._x+"|py="+actor._y+"|hp="+_root.hp+"|mp="+_root.mp+"|ex="+e._x+"|ey="+e._y+"|ehp="+e.hp+"|outer="+e._currentframe+"|enemy="+e.속._currentframe+"|marker="+e.공중.타격._currentframe+"|g="+e.중력+"|gacc="+e.중력가속도+"|zak="+_root.zak+"|fire_timer="+actor.작열시간._currentframe+"|fire_total="+actor.작열시간._totalframes+"|eun="+_root.eun+"|silver_timer="+actor.은탄시간._currentframe+"|silver_total="+actor.은탄시간._totalframes+"|floor="+floor._currentframe+"|floor_depth="+floor.getDepth()+"|floor_x="+floor._x+"|floor_y="+floor._y+"|r1503="+r._currentframe+"|r1503_serial="+this.pRSerial+"|r1502="+leaf._currentframe+"|r1502_serial="+this.pRLeafSerial+"|rloops="+this.pRLoops+"|c4="+_root.c4+"|c4container="+e.시포._currentframe+"|c4_attach_helper="+actor.동작.붙._currentframe+"|yroot="+y._currentframe+"|yx="+y._x+"|yy="+y._y+"|ysx="+y._xscale+"|ynormal="+y.속._currentframe+"|ytimer="+y.시간._currentframe+"|yfocus_timer="+y.시간2._currentframe+"|bk="+_root.bk+"|root_i="+_root.i);
    if(this.tick>=350&&this.tick<=450) {
        this.pBomb(e.시포.한놈,"one",tag);this.pBomb(e.시포.두식이,"two",tag);this.pBomb(e.시포.석삼,"three",tag);
    }
    this.pFireSample(tag);
    if(this.tick>=690) {
        this.pBullets(_root,"root",tag);this.pBullets(y,"yroot",tag);
        var normal=y.속.발사중;
        this.pYUnit(normal,-16383,4423,tag);this.pYUnit(normal,-16345,4433,tag);
        this.pYUnit(normal,-16258,4436,tag);this.pYUnit(normal,-16220,4459,tag);
    }
};
leibaObserver.pRemoveFire=function() {
    if(typeof(this.pFireClip)=="movieclip"&&this.pFireClip._parent==_root) {
        this.pEvent("remove_only_prior_fixture_fire","fixture_cleanup_before_independent_sample");
        this.pFireClip.removeMovieClip();
    }
    this.pFireClip=undefined;
};
leibaObserver.pSpawnFire=function() {
    this.pRemoveFire();this.pSeed(250);
    this.pFireAttempts++;this.pFireBranch=undefined;
    var key="__act02_fire_"+this.pFireAttempts;
    this.pFireClip=_root.attachMovie("익스플로젼",key,1047000);
    if(!this.pCheck("original_fire_symbol_created_"+this.pFireAttempts,this.pFireClip._totalframes==66))return;
    this.pFireClip._x=_root.적._x;this.pFireClip._y=_root.적._y;
    this.pEvent("attach_original731_random_unmodified","fixture_symbol_entry_bypasses_bullet_source");
    this.pSample("after_fire_attach");
};
leibaObserver.pFinish=function() {
    this.pCheck("fire_timer_on_and_natural_off",this.pFireOn!=undefined&&this.pFireOff>this.pFireOn);
    this.pCheck("silver_timer_on_and_natural_off",this.pSilverOn!=undefined&&this.pSilverOff>this.pSilverOn);
    this.pCheck("R_at_least_two_source30_loops_observed",this.pRLoops>=2);
    this.pCheck("default731_branch3_observed_without_random_override",this.pSeenBranch3);
    this.pCheck("default731_branch27_observed_without_random_override",this.pSeenBranch27);
    this.pCheck("Y_original_root_entry_observed",this.pYEntered);
    trace("ACT02_PERSIST_DONE|t="+this.tick+"|reason=scheduled_complete|failures="+this.pFailures+"|fire_on="+this.pFireOn+"|fire_off="+this.pFireOff+"|silver_on="+this.pSilverOn+"|silver_off="+this.pSilverOff+"|r_source_samples="+this.pRFrames+"|rloops="+this.pRLoops+"|r1503_instances="+this.pRSerial+"|r1502_instances="+this.pRLeafSerial+"|fire_attempts="+this.pFireAttempts+"|branch3="+this.pSeenBranch3+"|branch27="+this.pSeenBranch27+"|y_entered="+this.pYEntered+"|y_bullet_rows="+this.pYBulletRows+"|Key_unchanged="+(_global.Key==this.pKey&&_global.Key.isDown==this.pIsDown));
    this.fixture=undefined;trace("LEIBA_FIXTURE_DONE");
};

trace("ACT02_PERSIST_SCHEMA|version=1|fixture=act02-persistent|natural_input=false|source_scripts_replaced=false|Math_random_replaced=false|timer_fastforward=false|done_tick=780");
leibaObserver.fixture=function(t) {
    if(t==25)trace("ACT02_PERSIST_PROFILE|t="+t+"|weapon="+_root.스핏무기+"|armor="+_root.스핏압+"|necklace="+_root.스핏목걸이+"|master="+_root.weaponmaster+"|c4="+_root.c4+"|flying="+_root.플라잉+"|root_i="+_root.i);
    if(t==30) {_root.crt=0;_root.nan=0;_root.lightningdg=8;_root.lightningt=200;_root.gotoAndPlay(40);this.pEvent("selection_root40","fixture_selection_values_not_OS_click");}
    if(t==40) {this.pCheck("root40_advanced41",_root._currentframe==41);this.pCase="Q_timers";this.pSeed(520);}
    if(t==50)this.pEnter(18,"Q_fire_entry");
    if(t==60) {
        if(this.pCheck("Q_fire_choice_from_original_hold12",_root.일._currentframe==18&&_root.일.동작._currentframe==12)) {_root.일.동작.gotoAndPlay(13);this.pEvent("Q_fire_choice13","direct_choice_seek_not_arrow_key");}
    }
    if(t==90)this.pEnter(18,"Q_silver_entry");
    if(t==100) {
        if(this.pCheck("Q_silver_choice_from_original_hold12",_root.일._currentframe==18&&_root.일.동작._currentframe==12)) {_root.일.동작.gotoAndPlay(22);this.pEvent("Q_silver_choice22","direct_choice_seek_not_arrow_key");}
    }
    if(t==130){this.pCase="R_with_independent_Q_timers";this.pEnter(23,"R_entry");}
    if(t==355) {
        this.pCheck("R_finished_before_C4",_root.불장판._currentframe==1);
        this.pCase="C4_attach_detonate";this.pSeed(175);_root.c4=0;_root.적.시포.gotoAndStop(1);this.pEvent("clear_C4_before_three_original_attachments","fixture_baseline_only");
    }
    if(t==360||t==380||t==400)this.pEnter(21,"C4_attach_parent21_"+t);
    if(t==418) {this.pCheck("three_original_C4_counter",_root.c4==3);this.pCheck("three_original_attached_C4_container4",_root.적.시포._currentframe==4);}
    if(t==420)this.pEnter(22,"C4_detonate_parent22");
    if(t==448)this.pCheck("C4_original_cleanup_container1",_root.적.시포._currentframe==1);
    if(t>=460&&t<=668&&(t-460)%16==0&&!(this.pSeenBranch3&&this.pSeenBranch27)) {this.pCase="fire731_random_samples";this.pSpawnFire();}
    if(t==685){this.pRemoveFire();this.pCase="Y_original_entry_hosts";this.pSeed(250);}
    if(t==690)this.pEnter(24,"Y_entry_parent24");
    if(t>=30&&t<=780)this.pSample("tick");
    if(t==780)this.pFinish();
};
