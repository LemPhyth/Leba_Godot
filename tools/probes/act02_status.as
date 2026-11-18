// ACT02 controlled silver/freeze/sniper status fixture. Builder: act02-status.
// Original AS, Key, Math.random, timers and collision shapes are unchanged.
// Not OS input / not native Flash / not natural skill input acceptance.
// Run Hidden, volume0, isolated memory/config/cache. Done at tick480.
// 30 crt0/nan0/lightning8/200; root40 naturally enters training41.
// 40 enemy340/361 HP=hpm2000 instead of training1e22, player132.4/314.9.
// 60 direct parent19: original H child1->5 flight/contact/branches unchanged.
// Revision2 keeps run1 failures as evidence. Original1474 helper is offset
// about103px at f1: placing its parent at target-30 missed the target entirely.
// 110 use the actually H-frozen target; HP=hpm2000 only, no state/timer seek.
// 120 attach original1474, align its ORIGINAL helper bounds center to frozen
// body center minus25px. This is fixture placement, not a gameplay hitbox.
// 245 check whether original H froze and later restored the enemy.
// 320 independent ground reset;330 Qparent18;340 child22 from originalhold12.
// 355 attach original1474 with the same helper-based placement if eun==1.
// 410 reset;420 Tparent20;435 aim original reticle at normal body center and
// seek its original6789f2. No hit marker/HP/timer mutation after the shot.
// 465 seek root sniper7 to exit test mode;480 DONE.
// Independent resets clear old fixture bullets only, original status parent1,
// Q timers1, actor1, gravity0 and positions. Every reset/seek is an EVENT.
// Observer phase precedes remaining source callbacks. Frame snapshots are not
// a full intra-tick opcode trace; checks do not hardcode expected damage totals.

leibaObserver.stCase="boot";
leibaObserver.stFailures=0;
leibaObserver.stKey=_global.Key;
leibaObserver.stIsDown=_global.Key.isDown;
leibaObserver.stBullet=undefined;
leibaObserver.stBulletN=0;
leibaObserver.stFreezeSeen=false;
leibaObserver.stThawSeen=false;
leibaObserver.stFreezeFirst=undefined;
leibaObserver.stFreezeLast=undefined;
leibaObserver.stFrozenClip=undefined;
leibaObserver.stFrozenSerial=0;
leibaObserver.stFrozenInner=undefined;
leibaObserver.stInnerSerial=0;
leibaObserver.stSilverClip=undefined;
leibaObserver.stSilverSerial=0;
leibaObserver.stSilverSeen=false;
leibaObserver.stBulletHits=0;
leibaObserver.stFrozenBulletHit=false;
leibaObserver.stSilverBulletHit=false;
leibaObserver.stSniperSeen=false;
leibaObserver.stCheck=function(name,ok) {
    if(!ok)this.stFailures++;
    trace("ACT02_STATUS_CHECK|t="+this.tick+"|case="+this.stCase+"|name="+name+"|ok="+ok+"|failures="+this.stFailures);
    return ok;
};
leibaObserver.stEvent=function(event,mode) {
    trace("ACT02_STATUS_EVENT|t="+this.tick+"|ms="+getTimer()+"|case="+this.stCase+"|event="+event+"|mode="+mode);
};
leibaObserver.stAt=function(owner,depth) {
    if(typeof(owner)!="movieclip")return undefined;
    return owner.getInstanceAtDepth(depth);
};
leibaObserver.stHit=function(a,b) {
    if(typeof(a)!="movieclip"||typeof(b)!="movieclip")return undefined;
    return a.hitTest(b);
};
leibaObserver.stRemoveBullet=function() {
    if(typeof(this.stBullet)=="movieclip"&&this.stBullet._parent==_root) {
        this.stBullet.removeMovieClip();
        this.stEvent("remove_prior_fixture_bullet_only","independent_case_cleanup");
    }
    this.stBullet=undefined;
};
leibaObserver.stSeed=function(ex) {
    this.stRemoveBullet();
    _root.일.gotoAndStop(1);_root.일._x=132.4;_root.일._y=314.9;
    _root.일._xscale=Math.abs(_root.일._xscale);_root.bug1=1;
    _root.일.작열시간.gotoAndStop(1);_root.일.은탄시간.gotoAndStop(1);
    _root.적._x=ex;_root.적._y=361;_root.적.hp=2000;_root.적.hpm=2000;
    _root.적.중력=0;_root.적.중력가속도=0;
    _root.적.gotoAndStop(1);_root.적.속.gotoAndStop(1);_root.적.해골.gotoAndStop(1);
    _root.적.해골.기절.gotoAndStop(1);_root.적.해골.감전.gotoAndStop(1);
    _root.적.해골.닐스발사.gotoAndStop(1);
    this.stEvent("reset_player132_4_enemy"+ex+"_HP2000_ground_and_status_Qtimers1","explicit_fixture_baseline");
};
leibaObserver.stEnter=function(parent,label) {
    if(!this.stCheck(label+"_actor_idle",_root.일._currentframe==1))return;
    _root.일.gotoAndPlay(parent);
    this.stEvent(label,"direct_parent_seek_input_cost_CD_bypassed");
};
leibaObserver.stSpawnBullet=function(frozen) {
    var body=frozen?_root.적.속.얼음몸빵:_root.적.속.행동몸빵;
    if(!this.stCheck("bullet_target_body_exists",typeof(body)=="movieclip"))return;
    this.stRemoveBullet();
    this.stBulletN++;
    var b=body.getBounds(_root);
    var key="__act02_status_bullet_"+this.stBulletN;
    this.stBullet=_root.attachMovie("총알",key,1047100);
    if(!this.stCheck("original1474_bullet_created",this.stBullet._totalframes==11))return;
    var h=this.stAt(this.stBullet,-16383);
    if(!this.stCheck("original_bullet542_helper_exists",typeof(h)=="movieclip"))return;
    var hb=h.getBounds(_root);
    this.stBullet._x+=(b.xMin+b.xMax)/2-(hb.xMin+hb.xMax)/2-25;
    this.stBullet._y+=(b.yMin+b.yMax)/2-(hb.yMin+hb.yMax)/2;
    this.stEvent("attach_original1474_align_original_helper_center_to_target_minus25","fixture_spawn_not_original_X_muzzle_no_helper_or_damage_edit");
    this.stSample("after_bullet_attach");
};
leibaObserver.stHelper=function(owner,depth,label) {
    var c=this.stAt(owner,depth);
    if(typeof(c)!="movieclip")return;
    var b=c.getBounds(_root);
    trace("ACT02_STATUS_HELPER|t="+this.tick+"|case="+this.stCase+"|label="+label+"|parent="+c._parent+"|depth="+c.getDepth()+"|frame="+c._currentframe+"|total="+c._totalframes+"|xmin="+b.xMin+"|xmax="+b.xMax+"|ymin="+b.yMin+"|ymax="+b.yMax+"|normal="+this.stHit(c,_root.적.속.행동몸빵)+"|frozen="+this.stHit(c,_root.적.속.얼음몸빵)+"|air="+this.stHit(c,_root.적.공중));
};
leibaObserver.stSample=function(tag) {
    var e=_root.적;var a=_root.일.동작;var ice=e.속.얼음;
    var inner=ice.속;var silver=this.stAt(e.해골,-16382);
    if(typeof(ice)=="movieclip"&&ice!=this.stFrozenClip) {this.stFrozenClip=ice;this.stFrozenSerial++;}
    if(typeof(inner)=="movieclip"&&inner!=this.stFrozenInner) {this.stFrozenInner=inner;this.stInnerSerial++;}
    if(typeof(silver)=="movieclip"&&silver!=this.stSilverClip) {this.stSilverClip=silver;this.stSilverSerial++;}
    if(this.tick>=60&&this.tick<=245) {
        if(e.속._currentframe==63) {this.stFreezeSeen=true;if(this.stFreezeFirst==undefined)this.stFreezeFirst=this.tick;this.stFreezeLast=this.tick;}
        if(this.stFreezeSeen&&e.속._currentframe!=63)this.stThawSeen=true;
    }
    if(typeof(silver)=="movieclip")this.stSilverSeen=true;
    if(e.해골.닐스발사._currentframe==3)this.stSniperSeen=true;
    trace("ACT02_STATUS_STATE|t="+this.tick+"|ms="+getTimer()+"|case="+this.stCase+"|tag="+tag+"|phase=observer_before_remaining_callbacks|root="+_root._currentframe+"|actor="+_root.일._currentframe+"|action="+a._currentframe+"|px="+_root.일._x+"|py="+_root.일._y+"|ex="+e._x+"|ey="+e._y+"|ehp="+e.hp+"|outer="+e._currentframe+"|enemy="+e.속._currentframe+"|g="+e.중력+"|gacc="+e.중력가속도+"|air_marker="+e.공중.타격._currentframe+"|ice="+ice._currentframe+"|ice_total="+ice._totalframes+"|ice_serial="+this.stFrozenSerial+"|inner="+inner._currentframe+"|inner_serial="+this.stInnerSerial+"|skull="+e.해골._currentframe+"|silver="+silver._currentframe+"|silver_total="+silver._totalframes+"|silver_serial="+this.stSilverSerial+"|zak="+_root.zak+"|eun="+_root.eun+"|silver_timer="+_root.일.은탄시간._currentframe+"|sniper_root="+_root.저격._currentframe+"|sniper="+_root.저격.발사._currentframe+"|sniper_marker="+e.해골.닐스발사._currentframe+"|stun="+e.해골.기절._currentframe);
    if(_root.일._currentframe==19) {
        this.stHelper(a,-16293,"H4725_depth91");
        this.stHelper(a,-16291,"H4727_or_visual_depth93");
        this.stHelper(a,-16257,"H4727_or_flight_depth127");
    }
    if(typeof(this.stBullet)=="movieclip") {
        var h=this.stAt(this.stBullet,-16383);
        if(h.hita==1) {
            this.stBulletHits++;
            if(this.stCase=="basic_bullet_frozen_target")this.stFrozenBulletHit=true;
            if(this.stCase=="Q_silver_bullet")this.stSilverBulletHit=true;
        }
        trace("ACT02_STATUS_BULLET|t="+this.tick+"|case="+this.stCase+"|name="+this.stBullet._name+"|frame="+this.stBullet._currentframe+"|x="+this.stBullet._x+"|y="+this.stBullet._y+"|helper="+h._currentframe+"|hita="+h.hita+"|firec="+h.firec+"|selector="+h.총알._currentframe);
        this.stHelper(this.stBullet,-16383,"bullet542_depth1");
    }
    this.stHelper(_root.저격.발사,-16369,"sniper6788_depth15");
};
leibaObserver.stFinish=function() {
    this.stCheck("H_original_timeline_froze_enemy",this.stFreezeSeen);
    this.stCheck("H_original_outer_timer_restored_enemy",this.stThawSeen);
    this.stCheck("at_least_one_original_bullet_hita_observed",this.stBulletHits>0);
    this.stCheck("frozen_original_bullet_hita_observed",this.stFrozenBulletHit);
    this.stCheck("silver_original_bullet_hita_observed",this.stSilverBulletHit);
    this.stCheck("silver3991_observed",this.stSilverSeen);
    this.stCheck("sniper3945_frame3_observed",this.stSniperSeen);
    trace("ACT02_STATUS_DONE|t="+this.tick+"|failures="+this.stFailures+"|freeze_first="+this.stFreezeFirst+"|freeze_last="+this.stFreezeLast+"|bullet_count="+this.stBulletN+"|bullet_hit_rows="+this.stBulletHits+"|silver_instances="+this.stSilverSerial+"|Key_unchanged="+(_global.Key==this.stKey&&_global.Key.isDown==this.stIsDown));
    this.fixture=undefined;trace("LEIBA_FIXTURE_DONE");
};
trace("ACT02_STATUS_SCHEMA|version=2|fixture=act02-status|natural_input=false|source_scripts_replaced=false|Key_replaced=false|Math_random_replaced=false|done_tick=480");
leibaObserver.fixture=function(t) {
    if(t==25)trace("ACT02_STATUS_PROFILE|t="+t+"|weapon="+_root.스핏무기+"|armor="+_root.스핏압+"|necklace="+_root.스핏목걸이+"|passper="+_root.passper+"|root_i="+_root.i);
    if(t==30) {_root.crt=0;_root.nan=0;_root.lightningdg=8;_root.lightningt=200;_root.gotoAndPlay(40);this.stEvent("select_crt0_and_root40","fixture_selection_values");}
    if(t==40) {this.stCheck("training41",_root._currentframe==41);this.stCase="H_natural_action_timeline";this.stSeed(340);}
    if(t==60)this.stEnter(19,"H_parent19_default1_to5");
    if(t==110) {
        this.stCase="basic_bullet_frozen_target";
        this.stCheck("existing_H_frozen_target_for_basic_bullet",_root.적.속._currentframe==63);
        _root.적.hp=2000;_root.적.hpm=2000;
        this.stEvent("HP2000_only_preserve_actual_H_freeze_and_inner_clock","fixture_precision_baseline_no_state_seek");
    }
    if(t==120)this.stSpawnBullet(true);
    if(t==245) {this.stCheck("H_freeze_then_thaw_before_next_case",this.stFreezeSeen&&this.stThawSeen);}
    if(t==320) {this.stCase="Q_silver_bullet";this.stSeed(250);}
    if(t==330)this.stEnter(18,"Q_silver_parent18");
    if(t==340) {if(this.stCheck("Q_original_hold12",_root.일.동작._currentframe==12)) {_root.일.동작.gotoAndPlay(22);this.stEvent("choose_silver22","direct_choice_no_key_event");}}
    if(t==355) {if(this.stCheck("original_Q_timer_enabled_eun",_root.eun==1))this.stSpawnBullet(false);}
    if(t==410) {this.stCase="T_one_original_shot";this.stSeed(250);}
    if(t==420)this.stEnter(20,"T_parent20");
    if(t==435) {
        if(this.stCheck("original_T_root6_reticle1",_root.저격._currentframe==6&&_root.저격.발사._currentframe==1)) {
            var b=_root.적.속.행동몸빵.getBounds(_root);
            var p={x:(b.xMin+b.xMax)/2,y:(b.yMin+b.yMax)/2};
            _root.localToGlobal(p);_root.저격.globalToLocal(p);
            _root.저격.발사._x=p.x;_root.저격.발사._y=p.y;
            _root.저격.발사.gotoAndPlay(2);
            this.stEvent("aim_at_enemy_body_center_seek_original_shot2","fixture_aim_and_seek_no_Key_no_marker_edit");
            this.stSample("after_T_shot_seek");
        }
    }
    if(t==465) {_root.저격.gotoAndPlay(7);this.stEvent("exit_T_root7","fixture_end_window_cleanup");}
    if(t>=30&&t<=480)this.stSample("tick");
    if(t==480)this.stFinish();
};
