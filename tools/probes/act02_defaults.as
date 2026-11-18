// ACT02 controlled training-defaults fixture. Append after OBSERVER.
// Builder registration requested: --fixture act02-defaults -> this UTF-8 file.
// This file does NOT change or replace any original skill/timeline script.
// It does NOT generate native keyDown events and is NOT natural keyboard proof.
//
// Explicit interventions (all also have an ACT02_DEFAULTS_EVENT trace):
//  30: replay only the character-0 selection values crt=0/lightningdg=8/
//      lightningt=200 from button1858, choose nan=0, seek root40 with play().
//      Original root loading before30 and root40->41 timeline remain intact.
//      No weapon/unlock/HP/MP/cube defaults are substituted or repaired.
//  60..62: mock held F solely to prove original Key object's isDown override.
//      Holding does NOT dispatch clip keyDown; no F skill is inferred from it.
// 580: directly enter actor114 (F loading). Original6012 f13 creates stock5.
//      This bypasses the input gate/MP cost and does not test that gate/cost.
// 610: replay the minimal effects of 6895's original F keyDown: actor19,
//      action119, stock-1, icon.gotoAndPlay(2). This is explicitly an input-
//      effects replay, NOT execution of the original keyDown handler.
// 645: when idle, replay button8495: hp=200;mp=200;bar.gotoAndPlay(7).
// 670: directly enter actor13 (D), without replaying D's MP/cooldown input.
// 674: replay the same button8495 effects while D is still active.
// 740: restore original isDown and its READ_ONLY flag; emit DONE.
// No enemy position, enemy HP, player position/facing, stock load amount,
// animation speed, cooldown time, original timer or original save is edited.
// Use the parent's isolated memory-storage Ruffle run with --volume 0.
//
// Log registration / field schema:
// ACT02_DEFAULTS_SCHEMA: version, marker names, sample scheduling/phase.
// ACT02_DEFAULTS_PROFILE: observed initial equipment/unlock/cheat values.
// ACT02_DEFAULTS_EVENT: event, entry_mode, before/after; describes interventions.
// ACT02_DEFAULTS_STATE (bounded flat record, no recursively dumped objects):
// t=observer source tick;ms=getTimer;phase=observer callback before remaining
// source callbacks;tag=tick/before_*/after_*;root/actor/action=original frames;
// hp/hpm/mp/mpm=root values;bar=4391 frame;urlaa=root reset latch;
// za/s/d/q/t_slot/e/r/y/v/w/f/g/h=original skill-slot frames (not seconds);
// f_stock/g_stock/h_stock=HUD inventories;f_hud=6896 frame;f_icon=6895 frame;
// f_icon_depth/f_icon_total=resolved anonymous icon identity checks;
// f_icon_same=still same clip instance as immediately before idle reset;
// cubes=root 무큐;cube_floor_root/player(_type)=observed 무큐p value/type;
// y_ready_seen=ever observed original4078 at533 before any fixture reset;
// held_f/visible_f/global_f=controlled isDown validation, not keyDown delivery;
// source_calls=non-probe calls since preceding STATE;mock_total=their total;
// method_is_mock/object_same=this fixture's original-Key identity checks.
// ACT02_DEFAULTS_CHECK: assertions of fixture preconditions only, not a full
// gameplay verdict. ACT02_DEFAULTS_DONE reports coverage and restoration.
// LEIBA_FIXTURE_DONE is the existing runner stop marker.
//
// F icon is anonymous in XML:6896/f2/depth5/6895, AS depth5-16384=-16379.
// Resolve that exact depth and validate totalframes81; enumeration is only a
// diagnostic fallback. A missing/mismatched child skips the replay with a
// locating error; it never silently manufactures a replacement icon.

leibaObserver.act02OriginalKey = _global.Key;
leibaObserver.act02OriginalIsDown = _global.Key.isDown;
leibaObserver.act02RootHadKey = _root.hasOwnProperty("Key");
leibaObserver.act02RootKey = _root.Key;
leibaObserver.act02Held = {};
leibaObserver.act02Active = false;
leibaObserver.act02ProbeRead = false;
leibaObserver.act02Calls = 0;
leibaObserver.act02TotalCalls = 0;
leibaObserver.act02ThisMismatch = 0;
leibaObserver.act02Case = "natural_boot";
leibaObserver.act02Failures = 0;
leibaObserver.act02YReadyTick = undefined;
leibaObserver.act02ResetCount = 0;
leibaObserver.act02LoadedStock = undefined;
leibaObserver.act02ThrowReplayed = false;
leibaObserver.act02PreResetIcon = undefined;
leibaObserver.act02HeldVerified = false;
leibaObserver.act02Mock = function(code) {
    var o = _root.__leiba02_observer;
    if(!o.act02Active) return o.act02OriginalIsDown.apply(this,arguments);
    if(!o.act02ProbeRead) {
        o.act02Calls++;
        o.act02TotalCalls++;
        if(this != o.act02OriginalKey) o.act02ThisMismatch++;
    }
    return o.act02Held[code] == true;
};
ASSetPropFlags(_global.Key,"isDown",0,4);
_global.Key.isDown = leibaObserver.act02Mock;

leibaObserver.act02Event = function(event, mode) {
    trace("ACT02_DEFAULTS_EVENT|t="+this.tick+"|ms="+getTimer()+"|case="+this.act02Case+"|event="+event+"|entry_mode="+mode+"|root="+_root._currentframe+"|actor="+_root.일._currentframe+"|action="+_root.일.동작._currentframe);
};
leibaObserver.act02Check = function(name, ok) {
    if(!ok) this.act02Failures++;
    trace("ACT02_DEFAULTS_CHECK|t="+this.tick+"|name="+name+"|ok="+ok+"|failures="+this.act02Failures);
    return ok;
};
leibaObserver.act02Icon = function() {
    var owner = _root.게임오버.파열표시;
    if(owner == undefined) return undefined;
    var result = owner.getInstanceAtDepth(-16379);
    if(result != undefined && result._totalframes == 81) return result;
    for(var name in owner) {
        var candidate = owner[name];
        if(typeof(candidate) == "movieclip" && candidate._totalframes == 81 && candidate._parent == owner) return candidate;
    }
    return undefined;
};
leibaObserver.act02Sample = function(tag) {
    var b = _root.스킬창;
    var icon = this.act02Icon();
    var iconDepth = undefined;
    if(icon != undefined) iconDepth = icon.getDepth();
    this.act02ProbeRead = true;
    var visibleF = Key.isDown(70);
    var globalF = _global.Key.isDown(70);
    this.act02ProbeRead = false;
    trace("ACT02_DEFAULTS_STATE|t="+this.tick+"|ms="+getTimer()+"|case="+this.act02Case+"|phase=observer_before_remaining_callbacks|tag="+tag+"|root="+_root._currentframe+"|actor="+_root.일._currentframe+"|action="+_root.일.동작._currentframe+"|hp="+_root.hp+"|hpm="+_root.hpm+"|mp="+_root.mp+"|mpm="+_root.mpm+"|bar="+b._currentframe+"|urlaa="+_root.urlaa+"|za="+b.잭스파이크._currentframe+"|s="+b.라이징샷._currentframe+"|d="+b.크로스모어._currentframe+"|q="+b.작열탄._currentframe+"|t_slot="+b.닐스나이핑._currentframe+"|e="+b.시포._currentframe+"|r="+b.네이팜탄._currentframe+"|y="+b.블랙로즈._currentframe+"|v="+b.잡기스킬._currentframe+"|w="+b.빙결류탄._currentframe+"|f="+b.신스킬1._currentframe+"|g="+b.신스킬2._currentframe+"|h="+b.신스킬3._currentframe+"|f_stock="+_root.게임오버.파열표시.류탄+"|g_stock="+_root.게임오버.섬광표시.류탄+"|h_stock="+_root.게임오버.빙결표시.류탄+"|f_hud="+_root.게임오버.파열표시._currentframe+"|f_icon="+icon._currentframe+"|f_icon_depth="+iconDepth+"|f_icon_total="+icon._totalframes+"|f_icon_same="+(this.act02PreResetIcon!=undefined && icon==this.act02PreResetIcon)+"|cubes="+_root.무큐+"|cube_floor_root="+_root.무큐p+"|cube_floor_root_type="+typeof(_root.무큐p)+"|cube_floor_player="+_root.일.무큐p+"|cube_floor_player_type="+typeof(_root.일.무큐p)+"|y_ready_seen="+(this.act02YReadyTick!=undefined)+"|held_f="+(this.act02Held[70]==true)+"|visible_f="+visibleF+"|global_f="+globalF+"|source_calls="+this.act02Calls+"|mock_total="+this.act02TotalCalls+"|method_is_mock="+(_global.Key.isDown==this.act02Mock)+"|object_same="+(_global.Key==this.act02OriginalKey));
    this.act02Calls = 0;
};
leibaObserver.act02ResetButtonEffects = function(label) {
    this.act02Sample("before_"+label);
    _root.hp = 200;
    _root.mp = 200;
    _root.스킬창.gotoAndPlay(7);
    this.act02ResetCount++;
    this.act02Event(label,"button8495_effects_replay_not_OS_click");
    this.act02Sample("after_"+label);
};
leibaObserver.act02Finish = function(reason) {
    this.act02Active = false;
    this.act02Held = {};
    ASSetPropFlags(_global.Key,"isDown",0,4);
    _global.Key.isDown = this.act02OriginalIsDown;
    ASSetPropFlags(_global.Key,"isDown",4,0);
    _global.Key.isDown = this.act02Mock;
    var restoredFlag = _global.Key.isDown == this.act02OriginalIsDown;
    if(!restoredFlag) {
        ASSetPropFlags(_global.Key,"isDown",0,4);
        _global.Key.isDown = this.act02OriginalIsDown;
        ASSetPropFlags(_global.Key,"isDown",4,0);
    }
    trace("ACT02_DEFAULTS_DONE|t="+this.tick+"|reason="+reason+"|failures="+this.act02Failures+"|y_ready_tick="+this.act02YReadyTick+"|loaded_stock="+this.act02LoadedStock+"|throw_replayed="+this.act02ThrowReplayed+"|reset_count="+this.act02ResetCount+"|held_verified="+this.act02HeldVerified+"|mock_total="+this.act02TotalCalls+"|this_mismatch="+this.act02ThisMismatch+"|original_restored="+(_global.Key.isDown==this.act02OriginalIsDown)+"|read_only_restored="+restoredFlag+"|root_key_unchanged="+(_root.hasOwnProperty("Key")==this.act02RootHadKey && _root.Key==this.act02RootKey));
    this.fixture = undefined;
    trace("LEIBA_FIXTURE_DONE");
};

trace("ACT02_DEFAULTS_SCHEMA|version=1|fixture=act02-defaults|native_keydown_generated=false|natural_keyboard=false|samples=30..62_and_570..710_every_tick_else_25ticks|phase=observer_callback_with_immediate_post_intervention_samples|done_tick=740");
trace("ACT02_DEFAULTS_EVENT|t=0|event=install_original_Key_method_override|entry_mode=instrumentation|object_same="+(_global.Key==leibaObserver.act02OriginalKey)+"|method_is_mock="+(_global.Key.isDown==leibaObserver.act02Mock));

leibaObserver.fixture = function(t) {
    this.act02Active = t>=40 && t<740;
    this.act02Held = {};
    if(t>=60 && t<=62) this.act02Held[70]=true;
    if(t==25) {
        trace("ACT02_DEFAULTS_PROFILE|t="+t+"|crt="+_root.crt+"|nan="+_root.nan+"|weapon="+_root.스핏무기+"|armor="+_root.스핏압+"|ring="+_root.스핏반지+"|fly_c4="+_root.플라잉씨포+"|sonic="+_root.소닉+"|master="+_root.스핏마스터+"|awakening2="+_root.스핏2각기+"|weaponmaster="+_root.weaponmaster+"|thereisnospoon="+_root.thereisnospoon+"|whosyourdaddy="+_root.whosyourdaddy+"|cubes="+_root.무큐+"|lightningdg="+_root.lightningdg+"|lightningt="+_root.lightningt);
    }
    if(t==30) {
        this.act02Case="training_initialization";
        this.act02Sample("before_root40");
        _root.crt=0;
        _root.nan=0;
        _root.lightningdg=8;
        _root.lightningt=200;
        _root.gotoAndPlay(40);
        this.act02Event("select_crt0_lightning8_200_seek_root40","selection_values_replay_and_root_seek");
        this.act02Sample("after_root40");
    }
    if(t==40) {
        if(!this.act02Check("original_root40_advanced_to41",_root._currentframe==41)) {
            this.act02Sample("root_transition_failed");
            this.act02Finish("root_transition_failed");
            return;
        }
    }
    if(t==60) {
        this.act02ProbeRead=true;
        var localRead=Key.isDown(70);
        var globalRead=_global.Key.isDown(70);
        this.act02ProbeRead=false;
        this.act02HeldVerified=this.act02Check("held_method_installed_and_readback",_global.Key==this.act02OriginalKey && _global.Key.isDown==this.act02Mock && localRead==true && globalRead==true);
        this.act02Event("held_F_readback_only","mock_isDown_no_native_keydown");
        if(!this.act02HeldVerified) {
            this.act02Sample("held_install_failed");
            this.act02Finish("held_install_failed");
            return;
        }
    }
    if(this.act02ResetCount==0 && this.act02YReadyTick==undefined && _root.스킬창.블랙로즈._currentframe==533) {
        this.act02YReadyTick=t;
        this.act02Event("original_Y_first_ready533","observation_only");
        this.act02Sample("Y_first_ready");
    }
    if(t==580) {
        this.act02Case="F_load_direct_parent114";
        this.act02Sample("before_F_load");
        if(this.act02Check("F_load_actor_is_idle",_root.일._currentframe==1)) {
            _root.일.gotoAndPlay(114);
            this.act02Event("F_load_parent114_MP_gate_bypassed","direct_parent_seek_no_MP_cost_replay");
            this.act02Sample("after_F_load");
        }
    }
    if(t==605) {
        this.act02LoadedStock=_root.게임오버.파열표시.류탄;
        this.act02Check("original_F_load_stock5",this.act02LoadedStock==5);
        this.act02Check("original_F_icon81_exists",this.act02Icon()._totalframes==81);
    }
    if(t==610) {
        this.act02Case="F_throw_input_effects_replay";
        this.act02Sample("before_F_throw");
        var icon=this.act02Icon();
        if(this.act02Check("throw_replay_preconditions",_root.일._currentframe==1 && _root.게임오버.파열표시.류탄>0 && icon._currentframe==1 && icon._totalframes==81)) {
            _root.일.gotoAndPlay(19);
            _root.일.동작.gotoAndPlay(119);
            _root.게임오버.파열표시.류탄-=1;
            icon.gotoAndPlay(2);
            this.act02ThrowReplayed=true;
            this.act02Event("F_throw_actor19_child119_stock_minus1_icon_play2","HUD6895_keydown_effects_replay_not_dispatch");
            this.act02Sample("after_F_throw");
        }
    }
    if(t==645) {
        this.act02Case="reset_idle_during_F_icon_timer";
        this.act02PreResetIcon=this.act02Icon();
        if(this.act02Check("idle_reset_actor_is_idle",_root.일._currentframe==1)) this.act02ResetButtonEffects("reset_idle");
    }
    if(t==670) {
        this.act02Case="D_direct_parent13";
        this.act02Sample("before_D");
        if(this.act02Check("D_entry_actor_is_idle",_root.일._currentframe==1)) {
            _root.일.gotoAndPlay(13);
            this.act02Event("D_parent13_MP_CD_gates_bypassed","direct_parent_seek_no_MP_CD_replay");
            this.act02Sample("after_D");
        }
    }
    if(t==674) {
        this.act02Case="reset_during_original_D";
        if(this.act02Check("D_reset_actor_still13",_root.일._currentframe==13)) this.act02ResetButtonEffects("reset_D");
    }
    if((t>=30 && t<=62) || (t>=570 && t<=710) || (t>=30 && t%25==0)) this.act02Sample("tick");
    if(t==740) {
        this.act02Sample("final");
        this.act02Finish("scheduled_complete");
    }
};
