// ACT02 controlled A/W summons fixture. Append after the existing OBSERVER.
// Requested builder key: act02-summons. Original skill/clip/timer scripts and
// native property setters are NOT replaced. No OS or synthetic keyDown input.
// Run in isolated Ruffle memory storage/config/cache with --volume 0.
//
// Explicit interventions (each also logged):
// t30: crt0/nan0/lightning8/200; root.play40 -> original training41.
// t40: player132.4,314.9 facing right; enemy250,361 hp=hpm=2000, gravity0,
//      gacc0, outer1/action1. 2000 enables visible double-precision HP deltas;
//      it replaces training1e22 ONLY for this measurement. PlayerHP/MP untouched.
// t60: A flag=1 then actor.play113. Original load chooses child6010 frame21,
//      original actor observer attaches1108 at child25. Input/MP/CD bypassed.
// t210: remove only known A instances created since this fixture's first entry;
//       reset actor/enemy as above, enemy550. No unrelated objects removed.
// t240: same direct A entry. Enemy X is pinned550 on ticks211..440 UNTIL
//       this A's original wait child first reaches148. Every pin is logged in
//       PIN including before/after X (source enemy movement is not disabled).
//       At that point relocate enemy once to A.x+75 and release the pin:
//       intended outside wait bounds but inside blast, both hitTests logged.
//       This allows the original wait150 -> parent10 timeout, not contact2.
// t470: remove only tracked prior A; reset actor/enemy, enemy187.
// t490: A flag=0 then actor.play113; original6010 default1..10 attaches W
//       at child5. The original W contact/230 timer/blast scripts remain.
// t650: DONE. No source script is changed, no timers cancelled or clock sped.
//
// STATE once/tick30..650 + labelled immediate samples: source observer stage,
// root/actor/action; player position; enemy hp/hpm,position,outer/action,
// body/air/airmarker frames,gravity/gacc,mobsp; root.i and direct-entry count.
// OBJECT once/tick per enumerated root runner/mine: original key and _name,
// AS getDepth,parent path/frame,clip frame/total,x/y/scale,mobsp+typeof;
// independent wait child depth/frame, waiting hitTest vs normal/armor/frozen,
// blast child/frame and equivalent hitTests; getBounds(_root) numeric values.
// EVENT/CHECK/PROFILE/PIN distinguish interventions from original evolution.
// The observer samples before remaining queued source callbacks. Exact setter
// invocation is not hooked: undefined mobsp + actual finite position changes
// support host-behavior inference, not a claim of direct setter interception.

leibaObserver.sumCase = "natural_boot";
leibaObserver.sumFailures = 0;
leibaObserver.sumEntries = 0;
leibaObserver.sumTracked = [];
leibaObserver.sumIgnore = {};
leibaObserver.sumSeeded = false;
leibaObserver.sumPinEnemy = false;
leibaObserver.sumTimeoutRelocated = false;
leibaObserver.sumSawContact = false;
leibaObserver.sumSawTimeout = false;
leibaObserver.sumSawTimeoutBlast = false;
leibaObserver.sumTimeoutContactPremature = false;
leibaObserver.sumSawWContact = false;
leibaObserver.sumSawABlast = false;
leibaObserver.sumSawWBlast = false;
leibaObserver.sumInitialKey = _global.Key;
leibaObserver.sumInitialIsDown = _global.Key.isDown;

leibaObserver.sumKind = function(name) {
    if(name.indexOf("랜드러너") == 0) return "runner1108";
    if(name.indexOf("마인2") == 0) return "mine603";
    if(name.indexOf("마인") == 0) return "mine613";
    return undefined;
};
leibaObserver.sumCheck = function(name, ok) {
    if(!ok) this.sumFailures++;
    trace("ACT02_SUMMONS_CHECK|t="+this.tick+"|case="+this.sumCase+"|name="+name+"|ok="+ok+"|failures="+this.sumFailures);
    return ok;
};
leibaObserver.sumEvent = function(event, mode) {
    trace("ACT02_SUMMONS_EVENT|t="+this.tick+"|ms="+getTimer()+"|case="+this.sumCase+"|event="+event+"|mode="+mode+"|root="+_root._currentframe+"|actor="+_root.일._currentframe+"|action="+_root.일.동작._currentframe+"|root_i="+_root.i);
};
leibaObserver.sumOverlap = function(body, target) {
    if(typeof(body)!="movieclip" || typeof(target)!="movieclip") return undefined;
    return body.hitTest(target);
};
leibaObserver.sumTrack = function(clip, key, kind) {
    if(this.sumIgnore[key]==clip) return;
    for(var k=0;k<this.sumTracked.length;k++) if(this.sumTracked[k].clip==clip) return;
    this.sumTracked.push({clip:clip,key:key,kind:kind,created_case:this.sumCase,first_tick:this.tick});
    trace("ACT02_SUMMONS_DISCOVER|t="+this.tick+"|case="+this.sumCase+"|key="+key+"|name="+clip._name+"|kind="+kind+"|asdepth="+clip.getDepth()+"|parent="+clip._parent+"|frame="+clip._currentframe+"|total="+clip._totalframes);
};
leibaObserver.sumObject = function(clip, key, kind, tag) {
    var wait;
    var blast;
    if(kind=="runner1108" && clip._currentframe==1) wait=clip.getInstanceAtDepth(-16383);
    if(kind!="runner1108" && clip._currentframe==23) wait=clip.getInstanceAtDepth(-16348);
    if((kind=="runner1108" && clip._currentframe>=10 && clip._currentframe<=12) || (kind!="runner1108" && clip._currentframe>=30 && clip._currentframe<=32)) blast=clip.getInstanceAtDepth(-16369);
    var wb;
    var bb;
    if(wait!=undefined) wb=wait.getBounds(_root);
    if(blast!=undefined) bb=blast.getBounds(_root);
    var e=_root.적;
    trace("ACT02_SUMMONS_OBJECT|t="+this.tick+"|ms="+getTimer()+"|case="+this.sumCase+"|tag="+tag+"|key="+key+"|name="+clip._name+"|kind="+kind+"|asdepth="+clip.getDepth()+"|parent="+clip._parent+"|parentframe="+clip._parent._currentframe+"|frame="+clip._currentframe+"|total="+clip._totalframes+"|x="+clip._x+"|y="+clip._y+"|sx="+clip._xscale+"|sy="+clip._yscale+"|mobsp="+clip.mobsp+"|mobsp_type="+typeof(clip.mobsp)+"|wait="+wait._currentframe+"|wait_total="+wait._totalframes+"|wait_x="+wait._x+"|wait_y="+wait._y+"|wait_normal="+this.sumOverlap(e.속.행동몸빵,wait)+"|wait_armor="+this.sumOverlap(e.속.슈퍼아머,wait)+"|wait_frozen="+this.sumOverlap(e.속.얼음몸빵,wait)+"|wait_xmin="+wb.xMin+"|wait_xmax="+wb.xMax+"|wait_ymin="+wb.yMin+"|wait_ymax="+wb.yMax+"|blast="+blast._currentframe+"|blast_normal="+this.sumOverlap(e.속.행동몸빵,blast)+"|blast_armor="+this.sumOverlap(e.속.슈퍼아머,blast)+"|blast_frozen="+this.sumOverlap(e.속.얼음몸빵,blast)+"|blast_air="+this.sumOverlap(e.공중,blast)+"|blast_xmin="+bb.xMin+"|blast_xmax="+bb.xMax+"|blast_ymin="+bb.yMin+"|blast_ymax="+bb.yMax);
    if(this.sumCase=="A_contact" && kind=="runner1108" && clip._currentframe>=2 && clip._currentframe<=9) this.sumSawContact=true;
    if(this.sumCase=="A_timeout" && kind=="runner1108" && wait._currentframe>=148) this.sumSawTimeout=true;
    if(this.sumCase=="A_timeout" && kind=="runner1108" && clip._currentframe>=2 && clip._currentframe<=9) this.sumTimeoutContactPremature=true;
    if(this.sumCase=="A_timeout" && kind=="runner1108" && clip._currentframe>=10 && clip._currentframe<=12) this.sumSawTimeoutBlast=true;
    if(this.sumCase=="W_contact" && kind!="runner1108" && clip._currentframe>=24 && clip._currentframe<=29) this.sumSawWContact=true;
    if(kind=="runner1108" && clip._currentframe>=10 && clip._currentframe<=12) this.sumSawABlast=true;
    if(kind!="runner1108" && clip._currentframe>=30 && clip._currentframe<=32) this.sumSawWBlast=true;
};
leibaObserver.sumSample = function(tag) {
    var e=_root.적;
    var eb=e.속.행동몸빵.getBounds(_root);
    trace("ACT02_SUMMONS_STATE|t="+this.tick+"|ms="+getTimer()+"|case="+this.sumCase+"|phase=observer_before_remaining_callbacks|tag="+tag+"|root="+_root._currentframe+"|actor="+_root.일._currentframe+"|action="+_root.일.동작._currentframe+"|px="+_root.일._x+"|py="+_root.일._y+"|player_sx="+_root.일._xscale+"|bug1="+_root.bug1+"|hp="+_root.hp+"|mp="+_root.mp+"|ex="+e._x+"|ey="+e._y+"|ehp="+e.hp+"|ehpm="+e.hpm+"|outer="+e._currentframe+"|enemy="+e.속._currentframe+"|body="+e.속.행동몸빵._currentframe+"|air="+e.공중._currentframe+"|marker="+e.공중.타격._currentframe+"|g="+e.중력+"|gacc="+e.중력가속도+"|enemy_mobsp="+e.mobsp+"|enemy_mobsp_type="+typeof(e.mobsp)+"|body_xmin="+eb.xMin+"|body_xmax="+eb.xMax+"|body_ymin="+eb.yMin+"|body_ymax="+eb.yMax+"|root_i="+_root.i+"|root_i_type="+typeof(_root.i)+"|pin_enemy="+this.sumPinEnemy+"|entries="+this.sumEntries);
    for(var key in _root) {
        var clip=_root[key];
        var kind=this.sumKind(key);
        if(kind!=undefined && typeof(clip)=="movieclip" && clip._parent==_root) {
            this.sumTrack(clip,key,kind);
            this.sumObject(clip,key,kind,tag);
        }
    }
};
leibaObserver.sumSeed = function(ex) {
    this.sumSample("before_seed");
    _root.일.gotoAndStop(1);
    _root.일._x=132.4;
    _root.일._y=314.9;
    _root.일._xscale=Math.abs(_root.일._xscale);
    _root.bug1=1;
    _root.적._x=ex;
    _root.적._y=361;
    _root.적.hp=2000;
    _root.적.hpm=2000;
    _root.적.중력=0;
    _root.적.중력가속도=0;
    _root.적.gotoAndStop(1);
    _root.적.속.gotoAndStop(1);
    this.sumSeeded=true;
    this.sumEvent("seed_positions_facing_enemy2000_gravity0_ground_idle","explicit_fixture_not_original_training_hp");
    this.sumSample("after_seed");
};
leibaObserver.sumCleanRunner = function() {
    for(var k=0;k<this.sumTracked.length;k++) {
        var row=this.sumTracked[k];
        if(row.kind=="runner1108" && row.clip._parent==_root && _root[row.key]==row.clip) {
            trace("ACT02_SUMMONS_EVENT|t="+this.tick+"|case="+this.sumCase+"|event=remove_prior_fixture_runner|key="+row.key+"|asdepth="+row.clip.getDepth()+"|created_case="+row.created_case+"|first_tick="+row.first_tick);
            row.clip.removeMovieClip();
            this.sumCheck("prior_runner_removed_"+row.key,_root[row.key]==undefined);
        }
    }
};
leibaObserver.sumEnter = function(isA) {
    this.sumSample("before_entry");
    if(!this.sumCheck("entry_actor_idle",_root.일._currentframe==1)) return;
    if(!this.sumCheck("root_i_numeric",typeof(_root.i)=="number")) return;
    _root.스핏무기8=isA ? 1 : 0;
    _root.일.gotoAndPlay(113);
    this.sumEntries++;
    this.sumEvent(isA ? "A_flag1_parent113" : "W_flag0_parent113","direct_parent_seek_no_input_MP_CD_replay");
    this.sumSample("after_entry");
};
leibaObserver.sumFinish = function(reason) {
    this.sumCheck("A_contact_2_to9_seen",this.sumSawContact);
    this.sumCheck("A_timeout_reached148_before_relocation",this.sumSawTimeout && this.sumTimeoutRelocated);
    this.sumCheck("A_timeout_blast_without_contact_2_to9",this.sumSawTimeoutBlast && !this.sumTimeoutContactPremature);
    this.sumCheck("A_blast10_to12_seen",this.sumSawABlast);
    this.sumCheck("W_contact24_to29_seen",this.sumSawWContact);
    this.sumCheck("W_blast30_to32_seen",this.sumSawWBlast);
    trace("ACT02_SUMMONS_DONE|t="+this.tick+"|reason="+reason+"|failures="+this.sumFailures+"|entries="+this.sumEntries+"|contact="+this.sumSawContact+"|timeout="+this.sumSawTimeout+"|timeout_relocated="+this.sumTimeoutRelocated+"|timeout_blast="+this.sumSawTimeoutBlast+"|timeout_premature_contact="+this.sumTimeoutContactPremature+"|w_contact="+this.sumSawWContact+"|a_blast="+this.sumSawABlast+"|w_blast="+this.sumSawWBlast+"|Key_unchanged="+(_global.Key==this.sumInitialKey && _global.Key.isDown==this.sumInitialIsDown));
    this.fixture=undefined;
    trace("LEIBA_FIXTURE_DONE");
};

trace("ACT02_SUMMONS_SCHEMA|version=1|fixture=act02-summons|input=direct_parent_seek|native_keydown=false|source_scripts_replaced=false|setter_hooked=false|done_tick=650|hp_override=enemy2000_for_numeric_resolution|samples=every_tick30_to650_plus_interventions");
leibaObserver.fixture = function(t) {
    if(t==25) trace("ACT02_SUMMONS_PROFILE|t="+t+"|crt="+_root.crt+"|nan="+_root.nan+"|weapon="+_root.스핏무기+"|armor="+_root.스핏압+"|necklace="+_root.스핏목걸이+"|root_i="+_root.i+"|root_i_type="+typeof(_root.i)+"|thereisnospoon="+_root.thereisnospoon+"|whosyourdaddy="+_root.whosyourdaddy);
    if(t==30) {
        this.sumCase="training_initialization";
        _root.crt=0; _root.nan=0; _root.lightningdg=8; _root.lightningt=200;
        _root.gotoAndPlay(40);
        this.sumEvent("selection_values_seek_root40","fixture_selection_values_not_button_click");
    }
    if(t==40) {
        if(!this.sumCheck("original_root40_advanced_to41",_root._currentframe==41)) { this.sumFinish("root_transition_failed"); return; }
        for(var key in _root) if(this.sumKind(key)!=undefined && typeof(_root[key])=="movieclip") this.sumIgnore[key]=_root[key];
        this.sumCase="A_contact";
        this.sumSeed(250);
    }
    if(t==60) this.sumEnter(true);
    if(t==210) {
        this.sumCleanRunner();
        this.sumCase="A_timeout";
        this.sumSeed(550);
        this.sumPinEnemy=true;
    }
    if(t==240) this.sumEnter(true);
    if(t>210 && t<=440 && this.sumPinEnemy) {
        var relocated=false;
        for(var k=0;k<this.sumTracked.length;k++) {
            var row=this.sumTracked[k];
            if(row.created_case=="A_timeout" && row.kind=="runner1108" && row.clip._parent==_root && row.clip._currentframe==1) {
                var wait=row.clip.getInstanceAtDepth(-16383);
                if(wait._currentframe>=148) {
                    this.sumSample("before_timeout_target_relocation");
                    _root.적._x=row.clip._x+75;
                    this.sumPinEnemy=false;
                    this.sumTimeoutRelocated=true;
                    this.sumSawTimeout=true;
                    this.sumEvent("enemy_to_runner_x_plus75_release_pin","fixture_outside_wait_inside_future_blast");
                    this.sumCheck("timeout_relocated_enemy_outside_wait",this.sumOverlap(_root.적.속.행동몸빵,wait)==false);
                    this.sumSample("after_timeout_target_relocation");
                    relocated=true;
                }
            }
        }
        if(!relocated && this.sumPinEnemy) {
            var before=_root.적._x;
            _root.적._x=550;
            trace("ACT02_SUMMONS_PIN|t="+t+"|case="+this.sumCase+"|event=enemy_x_pin|before="+before+"|after="+_root.적._x+"|target=550");
        }
    }
    if(t==441 && this.sumPinEnemy) {
        this.sumPinEnemy=false;
        this.sumCheck("timeout_relocation_completed_by441",false);
        this.sumEvent("safety_release_enemy_pin","fixture_timeout_precondition_failed");
    }
    if(t==470) {
        this.sumCleanRunner();
        this.sumCase="W_contact";
        this.sumSeed(187);
    }
    if(t==490) this.sumEnter(false);
    if(t>=30 && t<=650) this.sumSample("tick");
    if(t==650) this.sumFinish("scheduled_complete");
};
