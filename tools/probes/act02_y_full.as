// Controlled original Y full lifetimes. Builder key: act02-y-full.
// Original scripts/Key/random/clocks/hosts/damage/markers/slot are NOT replaced.
// 30 original selection prerequisite values ->root40;40 fixture player132.4,
// enemy250/361 HP=hpm2000,g/gacc0,groundidle;50 direct original parent24.
// Observe source4491 phase2 ->292timer ->4 ->9exit ->1 without fast-forward.
// 390 second baseline enemy450/361 after first natural exit (same live scene,
// original dynamic children are NOT forcibly removed);400 direct parent24.
// 450 player430,parent2 once: source follow/move-hit alone selects walk and
// later normal. No manual summon phase/coordinate/timer or movement loop.
// 520 direct original parent25 only if playeridle/Yphase2; its source33 starts
// phase3; original81timer ends it and releases the source38 player hold.
// 700 DONE. Entry input/MP/cube gates and slot.stop2 are intentionally bypassed
// by direct parent entries, NOT written as fixture results. The untouched slot
// is traced, including original4491f4 restart, not claimed natural entry CD.
// Only initial/reset positions/HP/gravity and declared actor seeks are writes.
// HP changes are observed, never prefilled. Root/child attach mismatch and
// undefined/NaN counters remain original. No fixture bullet is instantiated.
// Snapshot phase: observer callback before remaining queued callbacks.

leibaObserver.yCase="boot";
leibaObserver.yFailures=0;
leibaObserver.yKey=_global.Key;
leibaObserver.yIsDown=_global.Key.isDown;
leibaObserver.yRandom=Math.random;
leibaObserver.yInstances={};
leibaObserver.yNextSerial=0;
leibaObserver.yFirst2=undefined;
leibaObserver.yFirst4=undefined;
leibaObserver.yFirst1=undefined;
leibaObserver.yFocus3=undefined;
leibaObserver.yFocus4=undefined;
leibaObserver.yFocus1=undefined;
leibaObserver.yWalk=false;
leibaObserver.yWalkStopped=false;
leibaObserver.yHelperContact=false;
leibaObserver.yBulletContact=false;
leibaObserver.yBulletHit=false;
leibaObserver.yHPLoss=false;
leibaObserver.yUnitRows=0;
leibaObserver.yBulletRows=0;
leibaObserver.yHelperRows=0;

leibaObserver.yCheck=function(name,ok) {
    if(!ok)this.yFailures++;
    trace("ACT02_Y_CHECK|t="+this.tick+"|case="+this.yCase+"|name="+name+"|ok="+ok+"|failures="+this.yFailures);
    return ok;
};
leibaObserver.yEvent=function(event,mode) {
    trace("ACT02_Y_EVENT|t="+this.tick+"|ms="+getTimer()+"|case="+this.yCase+"|event="+event+"|mode="+mode);
};
leibaObserver.yAt=function(owner,depth) {
    if(typeof(owner)!="movieclip")return undefined;
    return owner.getInstanceAtDepth(depth);
};
leibaObserver.yHit=function(a,b) {
    if(typeof(a)!="movieclip"||typeof(b)!="movieclip")return undefined;
    return a.hitTest(b);
};
leibaObserver.ySerial=function(c) {
    if(typeof(c)!="movieclip")return undefined;
    var key=String(c);
    var old=this.yInstances[key];
    if(old==undefined||old.clip!=c) {
        this.yNextSerial++;
        this.yInstances[key]={clip:c,serial:this.yNextSerial};
    }
    return this.yInstances[key].serial;
};
leibaObserver.ySeed=function(ex) {
    _root.일.gotoAndStop(1);_root.일._x=132.4;_root.일._y=314.9;
    _root.일._xscale=Math.abs(_root.일._xscale);_root.bug1=1;
    _root.적._x=ex;_root.적._y=361;_root.적.hp=2000;_root.적.hpm=2000;
    _root.적.중력=0;_root.적.중력가속도=0;
    _root.적.gotoAndStop(1);_root.적.속.gotoAndStop(1);
    this.yEvent("seed_player132_4_314_9_enemy"+ex+"_361_HP2000_ground_g0","explicit_case_baseline_only_no_summon_slot_marker_writes");
};
leibaObserver.yEnter=function(parent,label) {
    if(!this.yCheck(label+"_player_idle",_root.일._currentframe==1))return;
    if(parent==25&&!this.yCheck("focus_entry_requires_existing_phase2",_root.여거너._currentframe==2))return;
    _root.일.gotoAndPlay(parent);
    this.yEvent(label,"direct_original_parent_seek_input_MP_cubes_slot_stop_bypassed");
};
leibaObserver.yHelper=function(u,unitID,depth) {
    var h=this.yAt(u,depth);
    if(typeof(h)!="movieclip")return;
    var b=h.getBounds(_root);
    var n=this.yHit(h,_root.적.속.행동몸빵);
    var a=this.yHit(h,_root.적.공중);
    if(n||a)this.yHelperContact=true;
    this.yHelperRows++;
    trace("ACT02_Y_HELPER|t="+this.tick+"|case="+this.yCase+"|source_id=1140|unit_id="+unitID+"|unit_serial="+this.ySerial(u)+"|unit_frame="+u._currentframe+"|path="+h+"|serial="+this.ySerial(h)+"|parent="+h._parent+"|depth="+h.getDepth()+"|frame="+h._currentframe+"|total="+h._totalframes+"|x="+h._x+"|y="+h._y+"|sx="+h._xscale+"|sy="+h._yscale+"|normal="+n+"|air="+a+"|armor="+this.yHit(h,_root.적.속.슈퍼아머)+"|frozen="+this.yHit(h,_root.적.속.얼음몸빵)+"|xmin="+b.xMin+"|xmax="+b.xMax+"|ymin="+b.yMin+"|ymax="+b.yMax);
};
leibaObserver.yBullets=function(owner,label) {
    if(typeof(owner)!="movieclip")return;
    for(var key in owner) {
        var b=owner[key];
        if(key.indexOf("총알")!=0||typeof(b)!="movieclip"||b._parent!=owner)continue;
        var p={x:0,y:0};b.localToGlobal(p);_root.globalToLocal(p);
        var h=this.yAt(b,-16383);var r=h.getBounds(_root);
        var n=this.yHit(h,_root.적.속.행동몸빵);var a=this.yHit(h,_root.적.공중);
        if(n||a)this.yBulletContact=true;
        if(h.hita==1)this.yBulletHit=true;
        this.yBulletRows++;
        trace("ACT02_Y_BULLET|t="+this.tick+"|case="+this.yCase+"|host_label="+label+"|owner="+owner+"|owner_serial="+this.ySerial(owner)+"|key="+key+"|path="+b+"|serial="+this.ySerial(b)+"|parent="+b._parent+"|depth="+b.getDepth()+"|frame="+b._currentframe+"|total="+b._totalframes+"|x="+b._x+"|y="+b._y+"|sx="+b._xscale+"|root_x="+p.x+"|root_y="+p.y+"|root_lookup_same="+(_root[key]==b)+"|helper="+h._currentframe+"|helper_total="+h._totalframes+"|hita="+h.hita+"|normal="+n+"|air="+a+"|xmin="+r.xMin+"|xmax="+r.xMax+"|ymin="+r.yMin+"|ymax="+r.yMax);
    }
};
leibaObserver.yUnit=function(owner,depth,id,group) {
    var u=this.yAt(owner,depth);
    if(typeof(u)!="movieclip")return;
    var p={x:0,y:0};u.localToGlobal(p);_root.globalToLocal(p);
    this.yUnitRows++;
    trace("ACT02_Y_UNIT|t="+this.tick+"|case="+this.yCase+"|group="+group+"|source_id="+id+"|path="+u+"|serial="+this.ySerial(u)+"|parent="+u._parent+"|depth="+u.getDepth()+"|frame="+u._currentframe+"|total="+u._totalframes+"|i="+u.i+"|x="+u._x+"|y="+u._y+"|root_x="+p.x+"|root_y="+p.y);
    this.yBullets(u,"unit"+id);
    // Validate original parent frame ranges before identifying reused depths.
    var f=u._currentframe;
    if(id==4433&&f>=27&&f<=39)this.yHelper(u,id,-16298);
    if(id==4459&&f>=10&&f<=11)this.yHelper(u,id,-16343);
    if(id==4483&&f>=2&&f<=3)this.yHelper(u,id,-16345);
    if(id==4484&&f>=13&&f<=25)this.yHelper(u,id,-16335);
};
leibaObserver.ySample=function() {
    var y=_root.여거너;var e=_root.적;var s=_root.스킬창.블랙로즈;
    if(e.hp<2000)this.yHPLoss=true;
    if(this.yCase=="natural_normal_expiration") {
        if(y._currentframe==2&&this.yFirst2==undefined)this.yFirst2=this.tick;
        if(y._currentframe==4&&this.yFirst4==undefined)this.yFirst4=this.tick;
        if(y._currentframe==1&&this.yFirst4!=undefined&&this.yFirst1==undefined)this.yFirst1=this.tick;
    }
    if(this.yCase=="walk_stop_focus_expiration") {
        if(y._currentframe==2&&y.속._currentframe==2)this.yWalk=true;
        if(this.yWalk&&y._currentframe==2&&y.속._currentframe==1)this.yWalkStopped=true;
        if(y._currentframe==3&&this.yFocus3==undefined)this.yFocus3=this.tick;
        if(y._currentframe==4&&this.yFocus4==undefined)this.yFocus4=this.tick;
        if(y._currentframe==1&&this.yFocus4!=undefined&&this.yFocus1==undefined)this.yFocus1=this.tick;
    }
    var exit=this.yAt(y,-16383);
    trace("ACT02_Y_STATE|t="+this.tick+"|ms="+getTimer()+"|case="+this.yCase+"|phase=observer_before_remaining_callbacks|root="+_root._currentframe+"|actor="+_root.일._currentframe+"|action="+_root.일.동작._currentframe+"|px="+_root.일._x+"|py="+_root.일._y+"|hp="+_root.hp+"|mp="+_root.mp+"|cubes="+_root.무큐+"|bar="+_root.스킬창._currentframe+"|slot="+s._currentframe+"|slot_serial="+this.ySerial(s)+"|yroot="+y._currentframe+"|yserial="+this.ySerial(y)+"|yx="+y._x+"|yy="+y._y+"|ysx="+y._xscale+"|normal="+y.속._currentframe+"|normal_serial="+this.ySerial(y.속)+"|timer="+y.시간._currentframe+"|timer_serial="+this.ySerial(y.시간)+"|focus_timer="+y.시간2._currentframe+"|focus_timer_serial="+this.ySerial(y.시간2)+"|exit="+exit._currentframe+"|bk="+_root.bk+"|move_hit="+this.yHit(_root.일.중력몸빵,y.이동히트)+"|ex="+e._x+"|ey="+e._y+"|ehp="+e.hp+"|outer="+e._currentframe+"|enemy="+e.속._currentframe+"|marker="+e.공중.타격._currentframe+"|g="+e.중력+"|gacc="+e.중력가속도+"|root_i="+_root.i+"|y_i="+y.i);
    this.yBullets(_root,"root");this.yBullets(y,"yroot");
    if(y._currentframe==2) {
        if(y.속._currentframe==1) {
            var n=y.속.발사중;
            this.yUnit(n,-16383,4423,"normal");this.yUnit(n,-16345,4433,"normal");
            this.yUnit(n,-16258,4436,"normal");this.yUnit(n,-16220,4459,"normal");
        } else {
            this.yUnit(y.속,-16383,4461,"walk");this.yUnit(y.속,-16343,4462,"walk");
            this.yUnit(y.속,-16314,4463,"walk");this.yUnit(y.속,-16288,4464,"walk");
        }
    }
    if(y._currentframe==3) {
        var f=y.집중포화;
        this.yUnit(f,-16383,4482,"focus");this.yUnit(f,-16353,4483,"focus");
        this.yUnit(f,-16313,4484,"focus");this.yUnit(f,-16197,4485,"focus");
    }
};
leibaObserver.yFinish=function() {
    this.yCheck("normal_phase2_natural4_then1",this.yFirst2!=undefined&&this.yFirst4>this.yFirst2&&this.yFirst1>this.yFirst4);
    this.yCheck("follow_selected_walk_without_summon_seek",this.yWalk);
    this.yCheck("walk_returned_normal_before_focus",this.yWalkStopped);
    this.yCheck("focus_phase3_natural4_then1",this.yFocus3!=undefined&&this.yFocus4>this.yFocus3&&this.yFocus1>this.yFocus4);
    this.yCheck("focus_released_player_original_hold",_root.일._currentframe==1);
    this.yCheck("original1140_contact_observed",this.yHelperContact);
    this.yCheck("original_host_bullet_contact_observed",this.yBulletContact);
    this.yCheck("original_host_bullet_hita1_observed",this.yBulletHit);
    this.yCheck("actual_enemy_HP_decrease_observed",this.yHPLoss);
    this.yCheck("source_Key_and_random_unchanged",_global.Key==this.yKey&&_global.Key.isDown==this.yIsDown&&Math.random==this.yRandom);
    trace("ACT02_Y_DONE|t="+this.tick+"|failures="+this.yFailures+"|normal2="+this.yFirst2+"|normal4="+this.yFirst4+"|normal1="+this.yFirst1+"|walk="+this.yWalk+"|walk_stopped="+this.yWalkStopped+"|focus3="+this.yFocus3+"|focus4="+this.yFocus4+"|focus1="+this.yFocus1+"|helper_contact="+this.yHelperContact+"|bullet_contact="+this.yBulletContact+"|bullet_hita1="+this.yBulletHit+"|HP_decreased="+this.yHPLoss+"|unit_rows="+this.yUnitRows+"|bullet_rows="+this.yBulletRows+"|helper_rows="+this.yHelperRows);
    this.fixture=undefined;trace("LEIBA_FIXTURE_DONE");
};

trace("ACT02_Y_SCHEMA|version=1|fixture=act02-y-full|natural_input=false|source_replaced=false|random_replaced=false|timer_fastforward=false|slot_written=false|done_tick=700");
leibaObserver.fixture=function(t) {
    if(t==25)trace("ACT02_Y_PROFILE|t="+t+"|weapon="+_root.스핏무기+"|armor="+_root.스핏압+"|necklace="+_root.스핏목걸이+"|bracelet="+_root.스핏팔찌+"|master="+_root.weaponmaster+"|passper="+_root.passper+"|thereisnospoon="+_root.thereisnospoon+"|root_i="+_root.i);
    if(t==30){_root.crt=0;_root.nan=0;_root.lightningdg=8;_root.lightningt=200;_root.gotoAndPlay(40);this.yEvent("selection_root40","fixture_selection_prerequisites_not_OS");}
    if(t==40){this.yCheck("root40_naturally_reached41",_root._currentframe==41);this.yCase="natural_normal_expiration";this.ySeed(250);}
    if(t==50)this.yEnter(24,"normal_parent24");
    if(t==390){this.yCheck("first_summon_naturally_ended_before_second_case",_root.여거너._currentframe==1);this.yCase="walk_stop_focus_expiration";this.ySeed(450);}
    if(t==400)this.yEnter(24,"second_parent24");
    if(t==450){this.yCheck("movement_starts_with_phase2",_root.여거너._currentframe==2);_root.일._x=430;_root.일.gotoAndPlay(2);this.yEvent("player_x430_parent2_once","controlled_position_seek_follow_and_walk_remain_original");}
    if(t==520)this.yEnter(25,"focus_parent25");
    if(t>=30&&t<=700)this.ySample();
    if(t==700)this.yFinish();
};
