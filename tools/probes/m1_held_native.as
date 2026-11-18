// Append after OBSERVER. Controlled Key.isDown fixture, NOT natural input.
// The original Key object is preserved: no _root.Key shadow is introduced.
// Ruffle's builtin isDown has READ_ONLY (4); clear only that flag before the
// replacement, restore the true original function and flag 4 at source tick300.
// Outside the controlled interval, preserve native arguments AND callback this.
// Other interventions: root2/crt0/nan0/dialog9, direct jump95, fixed root x/facing,
// enemy x900 each sample (the original common boundary callback may clamp it).
// Success requires original non-probe calls plus actual source-clip behavior.
// Do not assume a shot period: source6's queued stop can compete with goto2.

_root.__m1NativeOriginalKey = _global.Key;
_root.__m1NativeOriginalIsDown = _global.Key.isDown;
_root.__m1NativeRootHadKey = _root.hasOwnProperty("Key");
_root.__m1NativePreviousRootKey = _root.Key;
_root.__m1NativeActive = false;
_root.__m1NativeProbeRead = false;
_root.__m1NativeHeld = {};
_root.__m1NativeTotal = 0;
_root.__m1NativeInterval = 0;
_root.__m1Native37 = 0;
_root.__m1Native39 = 0;
_root.__m1Native88 = 0;
_root.__m1NativeThisMismatch = 0;
_root.__m1NativeCallLines = 0;
_root.__m1NativeCase = "setup";
_root.__m1NativeSeenShots = {};
_root.__m1NativeShotTotal = 0;
_root.__m1NativeMock = function(code) {
    if(!_root.__m1NativeActive) {
        return _root.__m1NativeOriginalIsDown.apply(this,arguments);
    }
    var answer = _root.__m1NativeHeld[code] == true;
    if(!_root.__m1NativeProbeRead) {
        _root.__m1NativeTotal++;
        _root.__m1NativeInterval++;
        if(code == 37) _root.__m1Native37++;
        if(code == 39) _root.__m1Native39++;
        if(code == 88) _root.__m1Native88++;
        if(this != _root.__m1NativeOriginalKey) _root.__m1NativeThisMismatch++;
        if((code == 37 || code == 39 || code == 88) && _root.__m1NativeCallLines < 32) {
            trace("LEBA_M1_NATIVE_HELD_CALL|t="+_root.__leiba02_observer.tick+"|case="+_root.__m1NativeCase+"|code="+code+"|answer="+answer+"|this_key="+(this==_root.__m1NativeOriginalKey)+"|parent="+_root.일._currentframe+"|child="+_root.일.동작._currentframe+"|sub="+_root.일.동작.점프중._currentframe+"|px="+_root.일._x+"|face="+_root.bug1);
            _root.__m1NativeCallLines++;
        }
    }
    return answer;
};
ASSetPropFlags(_global.Key,"isDown",0,4);
_global.Key.isDown = _root.__m1NativeMock;
trace("LEBA_M1_NATIVE_HELD_INSTALL|object_same="+(_global.Key==_root.__m1NativeOriginalKey)+"|method_is_mock="+(_global.Key.isDown==_root.__m1NativeMock)+"|original_saved="+(_root.__m1NativeOriginalIsDown!=_root.__m1NativeMock)+"|root_key_unchanged="+(_root.hasOwnProperty("Key")==_root.__m1NativeRootHadKey && _root.Key==_root.__m1NativePreviousRootKey));

leibaObserver.fixture = function(t) {
    // Interval counters describe original calls since the previous sample.
    // Coordinates/frames are sampled before this tick's remaining actor callbacks.
    var previousCalls = _root.__m1NativeInterval;
    var previous37 = _root.__m1Native37;
    var previous39 = _root.__m1Native39;
    var previous88 = _root.__m1Native88;
    _root.__m1NativeInterval=0;
    _root.__m1Native37=0;
    _root.__m1Native39=0;
    _root.__m1Native88=0;
    _root.__m1NativeCallLines=0;
    _root.__m1NativeHeld={};
    _root.__m1NativeActive=(t>=40 && t<300);
    if(t == 30) { _root.crt=0; _root.nan=0; _root.gotoAndStop(2); }
    if(t == 40 || t == 50) {
        _root.대화창.gotoAndStop(9);
        _root.일.gotoAndStop(1);
        _root.일._x=250;
        _root.일._xscale=Math.abs(_root.일._xscale);
        _root.bug1=1;
    }
    if(t>=40 && t<300) _root.적._x=900;
    _root.__m1NativeCase="release";
    if(t>=50 && t<60) {
        _root.__m1NativeCase="ground_right";
        _root.__m1NativeHeld[39]=true;
    }
    if(t>=60 && t<70) {
        _root.__m1NativeCase="ground_both";
        _root.__m1NativeHeld[37]=true;
        _root.__m1NativeHeld[39]=true;
    }
    if(t>=70 && t<80) {
        _root.__m1NativeCase="ground_left";
        _root.__m1NativeHeld[37]=true;
    }
    if(t==110 || t==165 || t==220) {
        _root.일._x=250;
        _root.bug1=(t==220 ? -1 : 1);
        _root.일._xscale=Math.abs(_root.일._xscale)*_root.bug1;
        _root.일.gotoAndStop(95);
    }
    if(t>=110 && t<145) _root.__m1NativeCase="jump_x";
    if(t>=165 && t<200) _root.__m1NativeCase="jump_x_reverse_left";
    if(t>=220 && t<255) _root.__m1NativeCase="jump_x_reverse_right";
    if((t>=120 && t<145) || (t>=175 && t<200) || (t>=230 && t<255)) _root.__m1NativeHeld[88]=true;
    if(t>=185 && t<200) _root.__m1NativeHeld[37]=true;
    if(t>=240 && t<255) _root.__m1NativeHeld[39]=true;
    if(t>=40 && t<300) {
        _root.__m1NativeProbeRead=true;
        var visible37=Key.isDown(37);
        var visible39=Key.isDown(39);
        var visible88=Key.isDown(88);
        var global37=_global.Key.isDown(37);
        var global39=_global.Key.isDown(39);
        var global88=_global.Key.isDown(88);
        _root.__m1NativeProbeRead=false;
        var shotCount=0;
        var newCount=0;
        var shots="";
        var seenNow={};
        for(var n in _root.일) {
            if(n.indexOf("대각총알")==0) {
                var projectile=_root.일[n];
                shotCount++;
                if(_root.__m1NativeSeenShots[n]!=projectile) {
                    newCount++;
                    _root.__m1NativeShotTotal++;
                }
                seenNow[n]=projectile;
                shots+=n+":"+projectile._currentframe+":"+projectile._x+":"+projectile._y+",";
            }
        }
        _root.__m1NativeSeenShots=seenNow;
        trace("LEBA_M1_NATIVE_HELD|t="+t+"|case="+_root.__m1NativeCase+"|parent="+_root.일._currentframe+"|child="+_root.일.동작._currentframe+"|sub="+_root.일.동작.점프중._currentframe+"|sub_y="+_root.일.동작.점프중._y+"|sub_i="+_root.일.동작.점프중.i+"|move="+_root.일.이동._currentframe+"|body="+_root.일.몸빵._currentframe+"|px="+_root.일._x+"|py="+_root.일._y+"|face="+_root.bug1+"|held37="+(_root.__m1NativeHeld[37]==true)+"|held39="+(_root.__m1NativeHeld[39]==true)+"|held88="+(_root.__m1NativeHeld[88]==true)+"|visible37="+visible37+"|visible39="+visible39+"|visible88="+visible88+"|global37="+global37+"|global39="+global39+"|global88="+global88+"|mock_calls="+previousCalls+"|mock37="+previous37+"|mock39="+previous39+"|mock88="+previous88+"|mock_total="+_root.__m1NativeTotal+"|this_mismatch="+_root.__m1NativeThisMismatch+"|method_is_mock="+(_global.Key.isDown==_root.__m1NativeMock)+"|object_same="+(_global.Key==_root.__m1NativeOriginalKey)+"|shot_count="+shotCount+"|new_shots="+newCount+"|shot_total="+_root.__m1NativeShotTotal+"|shots="+shots);
    }
    if(t==300) {
        _root.__m1NativeActive=false;
        _root.__m1NativeHeld={};
        _global.Key.isDown=_root.__m1NativeOriginalIsDown;
        ASSetPropFlags(_global.Key,"isDown",4,0);
        // Attempted write must now be rejected. Recover the original again if
        // the host unexpectedly fails the flag test; never leave the mock active.
        _global.Key.isDown=_root.__m1NativeMock;
        var readOnlyRestored=(_global.Key.isDown==_root.__m1NativeOriginalIsDown);
        if(!readOnlyRestored) {
            ASSetPropFlags(_global.Key,"isDown",0,4);
            _global.Key.isDown=_root.__m1NativeOriginalIsDown;
            ASSetPropFlags(_global.Key,"isDown",4,0);
        }
        trace("LEBA_M1_NATIVE_HELD_DONE|t="+t+"|mock_total="+_root.__m1NativeTotal+"|shot_total="+_root.__m1NativeShotTotal+"|this_mismatch="+_root.__m1NativeThisMismatch+"|object_same="+(_global.Key==_root.__m1NativeOriginalKey)+"|original_restored="+(_global.Key.isDown==_root.__m1NativeOriginalIsDown)+"|read_only_restored="+readOnlyRestored+"|root_key_unchanged="+(_root.hasOwnProperty("Key")==_root.__m1NativeRootHadKey && _root.Key==_root.__m1NativePreviousRootKey));
        this.fixture=undefined;
    }
};
