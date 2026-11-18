// M1 controlled original-Z timer fixture. NOT natural keyboard gameplay.
// Interventions: root/actor seeks, fixed setup positions/facing, enemy gravity
// seeds and forced interruption. Original Z hitTests and timer bodies remain.
// Wrappers delegate the exact arguments and callback this; only trace is added.
leibaObserver.zNativeInterval = _global.setInterval;
leibaObserver.zNativeTimeout = _global.setTimeout;
leibaObserver.zNativeClearInterval = _global.clearInterval;
leibaObserver.zPhase = "setup";
leibaObserver.zTimerTrace = function(event, id, delay) {
    trace("LEBA_M1_Z_TIMER|event="+event+"|ms="+getTimer()+"|t="+this.tick+"|phase="+this.zPhase+"|id="+id+"|delay="+delay+"|global="+_root.flyInt+"|root="+_root._currentframe+"|parent="+_root.일._currentframe+"|child="+_root.일.동작._currentframe+"|cx="+_root.일.동작._x+"|px="+_root.일._x+"|ex="+_root.적._x+"|ey="+_root.적._y+"|hp="+_root.적.hp+"|g="+_root.적.중력+"|gacc="+_root.적.중력가속도+"|outer="+_root.적._currentframe+"|air="+_root.적.공중._currentframe+"|marker="+_root.적.공중.타격._currentframe+"|face="+_root.일face);
};
_global.setInterval = function() {
    var observer = _root.__leiba02_observer;
    var passed = [];
    for(var i=0;i<arguments.length;i++) passed.push(arguments[i]);
    var id;
    if(typeof(passed[0]) == "function") {
        var originalCallback = passed[0];
        passed[0] = function() {
            observer.zTimerTrace("interval_before",id,undefined);
            var result = originalCallback.apply(this,arguments);
            observer.zTimerTrace("interval_after",id,undefined);
            return result;
        };
    }
    id = observer.zNativeInterval.apply(this,passed);
    observer.zTimerTrace("interval_create",id,arguments[1]);
    return id;
};
_global.setTimeout = function() {
    var observer = _root.__leiba02_observer;
    var passed = [];
    for(var i=0;i<arguments.length;i++) passed.push(arguments[i]);
    var id;
    if(typeof(passed[0]) == "function") {
        var originalCallback = passed[0];
        passed[0] = function() {
            observer.zTimerTrace("timeout_before",id,undefined);
            var result = originalCallback.apply(this,arguments);
            observer.zTimerTrace("timeout_after",id,undefined);
            return result;
        };
    }
    id = observer.zNativeTimeout.apply(this,passed);
    observer.zTimerTrace("timeout_create",id,arguments[1]);
    return id;
};
_global.clearInterval = function() {
    var observer = _root.__leiba02_observer;
    observer.zTimerTrace("interval_clear",arguments[0],undefined);
    return observer.zNativeClearInterval.apply(this,arguments);
};
leibaObserver.zSeed = function(px, ex, ey, gravity, acceleration, air) {
    _root.일._x=px;
    _root.일._xscale=Math.abs(_root.일._xscale);
    _root.bug1=1;
    _root.적._x=ex;
    _root.적._y=ey;
    _root.적.중력=gravity;
    _root.적.중력가속도=acceleration;
    _root.적.gotoAndStop(air ? 2 : 1);
    if(air) _root.적.공중.gotoAndStop(1);
    this.zTimerTrace("fixture_seed",undefined,undefined);
};
leibaObserver.fixture = function(t) {
    if(t == 30) { _root.crt=0; _root.nan=0; _root.gotoAndStop(2); }
    if(t == 40) { _root.대화창.gotoAndStop(9); _root.일.gotoAndStop(1); }
    if(t == 60) {
        this.zPhase="miss_existing_air_normal_finish";
        this.zSeed(40,330,220,-20,0.1,true);
        _root.일.gotoAndStop(5);
        this.zTimerTrace("fixture_parent5",undefined,undefined);
    }
    if(t == 95) {
        this.zPhase="ground_contact_normal_finish";
        _root.일.gotoAndStop(1);
        this.zSeed(200,240,360.15,1e-9,0,false);
    }
    if(t == 100) {
        _root.일.gotoAndStop(5);
        this.zTimerTrace("fixture_parent5",undefined,undefined);
    }
    if(t == 120) {
        this.zPhase="repeat_old_timeout_clears_current_id";
        _root.일.gotoAndStop(1);
        this.zSeed(40,330,180,-25,0.1,true);
        _root.일.gotoAndStop(5);
        this.zTimerTrace("fixture_parent5",undefined,undefined);
    }
    if(t == 129) {
        // Remove the old action before re-entering; same-parent goto alone
        // need not recreate a child. This deliberately bypasses MP/cooldown.
        _root.일.gotoAndStop(1);
        _root.일.gotoAndStop(5);
        this.zTimerTrace("fixture_remove_and_repeat",undefined,undefined);
    }
    if(t == 137) {
        this.zPhase="forced_interrupt_after_timer_creation";
        _root.일.gotoAndStop(14);
        this.zTimerTrace("fixture_forced_hurt",undefined,undefined);
    }
    if(t >= 40 && t <= 180) this.zTimerTrace("tick_sample",undefined,undefined);
    if(t == 180) {
        // Source timeouts have had >1.5 seconds after the last creation.
        // Restore only the instrumentation; do not clear source gameplay IDs.
        _global.setInterval=this.zNativeInterval;
        _global.setTimeout=this.zNativeTimeout;
        _global.clearInterval=this.zNativeClearInterval;
        trace("LEBA_M1_Z_TIMER|event=wrappers_restored|ms="+getTimer()+"|t="+t);
        trace("LEIBA_FIXTURE_DONE");
        this.fixture=undefined;
    }
};
