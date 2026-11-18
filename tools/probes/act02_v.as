// ACT02 V capture fixture, builder key act02-v. Separate from status probe.
// No original scripts, Key, random, collision shape, zab result or pren value
// are replaced during actions. Direct parent98 entries bypass input/MP/CD.
// t30 crt0/nan0/lightning8/200 and root40 -> original training41.
// t40 independent baseline: player132.4/314.9 right, enemy185/361 HP2000;
// t42 parent98. Original5678 must decide capture, anchor and termination.
// t150 independent baseline enemy550; t160 parent98 empty attempt.
// t240 DONE. No enemy pin, no goto15/68/70, no source-time acceleration.
// Baselines explicitly reset zab/pren to0 before entry only; never set zab1.
// Per-tick STATE includes actor/child positions, source anchor raw formula,
// actual enemy coordinates/HP/gravity/air marker, zab/pren and helper clocks.
// HELPER records original hitTests, local transforms and world bounds, not
// a PNG-derived collision. Same observer phase as prior source probes.

leibaObserver.vCase="boot";
leibaObserver.vFailures=0;
leibaObserver.vKey=_global.Key;
leibaObserver.vIsDown=_global.Key.isDown;
leibaObserver.vSawCapture=false;
leibaObserver.vSawPren2=false;
leibaObserver.vSawSuccessEnd=false;
leibaObserver.vSawEmptyCapture=false;
leibaObserver.vSawEmptyEnd=false;
leibaObserver.vFirst651=undefined;
leibaObserver.vMarkerRows=0;
leibaObserver.vCheck=function(name,ok) {
    if(!ok)this.vFailures++;
    trace("ACT02_V_CHECK|t="+this.tick+"|case="+this.vCase+"|name="+name+"|ok="+ok+"|failures="+this.vFailures);
    return ok;
};
leibaObserver.vEvent=function(event,mode) {
    trace("ACT02_V_EVENT|t="+this.tick+"|ms="+getTimer()+"|case="+this.vCase+"|event="+event+"|mode="+mode);
};
leibaObserver.vAt=function(owner,depth) {
    if(typeof(owner)!="movieclip")return undefined;
    return owner.getInstanceAtDepth(depth);
};
leibaObserver.vHit=function(a,b) {
    if(typeof(a)!="movieclip"||typeof(b)!="movieclip")return undefined;
    return a.hitTest(b);
};
leibaObserver.vSeed=function(ex) {
    _root.일.gotoAndStop(1);_root.일._x=132.4;_root.일._y=314.9;
    _root.일._xscale=Math.abs(_root.일._xscale);_root.bug1=1;
    _root.zab=0;_root.pren=0;
    _root.적._x=ex;_root.적._y=361;_root.적.hp=2000;_root.적.hpm=2000;
    _root.적.중력=0;_root.적.중력가속도=0;
    _root.적.gotoAndStop(1);_root.적.속.gotoAndStop(1);
    _root.적.해골.gotoAndStop(1);
    this.vEvent("baseline_player132_4_enemy"+ex+"_HP2000_ground_zab0_pren0","explicit_fixture_before_action_only");
};
leibaObserver.vEnter=function() {
    if(!this.vCheck("entry_actor_idle",_root.일._currentframe==1))return;
    _root.일.gotoAndPlay(98);
    this.vEvent("original_parent98_entry","direct_parent_seek_input_cost_CD_bypassed_no_zab_result");
    this.vSample("after_entry");
};
leibaObserver.vHelper=function(owner,depth,label) {
    var h=this.vAt(owner,depth);
    if(typeof(h)!="movieclip")return;
    var b=h.getBounds(_root);var p={x:0,y:0};h.localToGlobal(p);_root.globalToLocal(p);
    trace("ACT02_V_HELPER|t="+this.tick+"|case="+this.vCase+"|label="+label+"|action="+owner._currentframe+"|depth="+h.getDepth()+"|frame="+h._currentframe+"|total="+h._totalframes+"|x="+h._x+"|y="+h._y+"|sx="+h._xscale+"|sy="+h._yscale+"|world_x="+p.x+"|world_y="+p.y+"|xmin="+b.xMin+"|xmax="+b.xMax+"|ymin="+b.yMin+"|ymax="+b.yMax+"|normal="+this.vHit(h,_root.적.속.행동몸빵)+"|armor="+this.vHit(h,_root.적.속.슈퍼아머)+"|frozen="+this.vHit(h,_root.적.속.얼음몸빵)+"|air="+this.vHit(h,_root.적.공중));
};
leibaObserver.vSample=function(tag) {
    var p=_root.일;var a=p.동작;var e=_root.적;
    var anchor=this.vAt(a,-16249);var shot=this.vAt(a,-16247);
    var sign=p._xscale/Math.abs(p._xscale);
    var anchorActive=p._currentframe==98&&a._currentframe>=15&&a._currentframe<68&&typeof(anchor)=="movieclip";
    var formulaX=anchorActive?a._x*sign+p._x+anchor._x*sign:undefined;
    var formulaY=anchorActive?a._y+p._y+anchor._y:undefined;
    if(this.vCase=="capture_success_attempt") {
        if(_root.zab==1)this.vSawCapture=true;
        if(_root.pren==2)this.vSawPren2=true;
        if(this.vSawCapture&&p._currentframe==1&&_root.zab==0&&_root.pren==0)this.vSawSuccessEnd=true;
    }
    if(this.vCase=="empty_attempt") {
        if(_root.zab!=0)this.vSawEmptyCapture=true;
        if(this.tick>160&&p._currentframe==1)this.vSawEmptyEnd=true;
    }
    if(typeof(shot)=="movieclip"&&this.vFirst651==undefined)this.vFirst651=this.tick;
    if(e.공중.타격._currentframe==2)this.vMarkerRows++;
    trace("ACT02_V_STATE|t="+this.tick+"|ms="+getTimer()+"|case="+this.vCase+"|tag="+tag+"|phase=observer_before_remaining_callbacks|root="+_root._currentframe+"|actor="+p._currentframe+"|action="+a._currentframe+"|px="+p._x+"|py="+p._y+"|player_sx="+p._xscale+"|child_x="+a._x+"|child_y="+a._y+"|zab="+_root.zab+"|pren="+_root.pren+"|ex="+e._x+"|ey="+e._y+"|ehp="+e.hp+"|outer="+e._currentframe+"|enemy="+e.속._currentframe+"|g="+e.중력+"|gacc="+e.중력가속도+"|marker="+e.공중.타격._currentframe+"|anchor_active="+anchorActive+"|anchor_frame="+anchor._currentframe+"|anchor_x="+anchor._x+"|anchor_y="+anchor._y+"|formula_x="+formulaX+"|formula_y="+formulaY+"|shot="+shot._currentframe+"|hp="+_root.hp);
    if(p._currentframe==98) {
        this.vHelper(a,-16289,"capture_or_lift1234_depth95");
        if(a._currentframe<68)this.vHelper(a,-16249,"anchor5652_depth135");
        else this.vHelper(a,-16249,"final651_depth135");
        this.vHelper(a,-16247,"repeated651_depth137");
    }
};
leibaObserver.vFinish=function() {
    this.vCheck("source_selected_zab1",this.vSawCapture);
    this.vCheck("source_pren2_seen",this.vSawPren2);
    this.vCheck("success_source_returned_idle_zab0_pren0",this.vSawSuccessEnd);
    this.vCheck("empty_no_zab_selected",!this.vSawEmptyCapture);
    this.vCheck("empty_source_returned_idle",this.vSawEmptyEnd);
    this.vCheck("source651_seen",this.vFirst651!=undefined);
    trace("ACT02_V_DONE|t="+this.tick+"|failures="+this.vFailures+"|first651="+this.vFirst651+"|marker2_rows="+this.vMarkerRows+"|Key_unchanged="+(_global.Key==this.vKey&&_global.Key.isDown==this.vIsDown));
    this.fixture=undefined;trace("LEIBA_FIXTURE_DONE");
};
trace("ACT02_V_SCHEMA|version=1|fixture=act02-v|natural_input=false|original_scripts_replaced=false|zab_result_forced=false|done_tick=240");
leibaObserver.fixture=function(t) {
    if(t==25)trace("ACT02_V_PROFILE|t="+t+"|weapon="+_root.스핏무기+"|armor="+_root.스핏압+"|necklace="+_root.스핏목걸이+"|root_i="+_root.i);
    if(t==30) {_root.crt=0;_root.nan=0;_root.lightningdg=8;_root.lightningt=200;_root.gotoAndPlay(40);this.vEvent("selection_crt0_root40","fixture_selection_values");}
    if(t==40) {this.vCheck("training41",_root._currentframe==41);this.vCase="capture_success_attempt";this.vSeed(185);}
    if(t==42)this.vEnter();
    if(t==145)this.vCheck("first_action_finished_before_reset",_root.일._currentframe==1);
    if(t==150) {this.vCase="empty_attempt";this.vSeed(550);}
    if(t==160)this.vEnter();
    if(t>=30&&t<=240)this.vSample("tick");
    if(t==240)this.vFinish();
};
