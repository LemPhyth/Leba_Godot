// Append after the existing OBSERVER, which creates leibaObserver.
// This is a controlled diagnostic, NOT natural keyboard evidence.
// It shadows _root.Key with an ordinary object; _global.Key is never modified.
// Interventions: startup root2/crt0/nan0/dialog9; direct player goto95;
// reset player x250/facing1 at each case; keep enemy x900 during sampling;
// scripted held states. No original script replacement, save or audio action.
// Success requires both non-probe call counters AND actual original-clip
// displacement/subframe/shots. Self-query returning true alone proves nothing.

_root.__m1_originalKey = _global.Key;
_root.__m1_originalIsDown = _global.Key.isDown;
_root.__m1_rootHadKey = _root.hasOwnProperty("Key");
_root.__m1_previousRootKey = _root.Key;
_root.__m1held = {};
_root.__m1ProbeRead = false;
_root.__m1MockTotal = 0;
_root.__m1MockInterval = 0;
_root.__m1Mock39 = 0;
_root.__m1Mock88 = 0;
_root.__m1CallLines = 0;
_root.__m1Shadow = new Object();
_root.__m1Shadow.__proto__ = _global.Key;
_root.__m1Shadow.isDown = function(code) {
    var answer = _root.__m1held[code] == true;
    if(!_root.__m1ProbeRead) {
        _root.__m1MockTotal++;
        _root.__m1MockInterval++;
        if(code == 39) _root.__m1Mock39++;
        if(code == 88) _root.__m1Mock88++;
        if((code == 37 || code == 39 || code == 88) && _root.__m1CallLines < 16) {
            trace("LEBA_M1_SHADOW_CALL|t="+_root.__leiba02_observer.tick+"|code="+code+"|answer="+answer+"|parent="+_root.일._currentframe+"|child="+_root.일.동작._currentframe+"|sub="+_root.일.동작.점프중._currentframe);
            _root.__m1CallLines++;
        }
    }
    return answer;
};
_root.Key = _root.__m1Shadow;

leibaObserver.fixture = function(t) {
    // Counters below cover original callbacks since the previous fixture call.
    // Calls made by this fixture's own resolution checks are explicitly excluded.
    var previousCalls = _root.__m1MockInterval;
    var previous39 = _root.__m1Mock39;
    var previous88 = _root.__m1Mock88;
    _root.__m1MockInterval = 0;
    _root.__m1Mock39 = 0;
    _root.__m1Mock88 = 0;
    _root.__m1CallLines = 0;
    _root.__m1held = {};
    if(t == 30) { _root.crt=0; _root.nan=0; _root.gotoAndStop(2); }
    if(t == 40) { _root.대화창.gotoAndStop(9); _root.일.gotoAndStop(1); _root.일._x=250; }
    if(t >= 40 && t < 300) _root.적._x=900;
    if(t >= 60 && t < 80) _root.__m1held[39]=true;
    if(t == 110 || t == 160 || t == 210 || t == 250) {
        _root.일._x=250;
        _root.일._xscale=Math.abs(_root.일._xscale);
        _root.bug1=1;
        _root.일.gotoAndStop(95);
    }
    if(t >= 115 && t < 135) _root.__m1held[39]=true;
    if(t >= 170 && t < 190 || t >= 220 && t < 240 || t >= 260 && t < 280) _root.__m1held[88]=true;
    if(t >= 220 && t < 240) _root.__m1held[37]=true;
    if(t >= 260 && t < 280) _root.__m1held[39]=true;
    if(t >= 40 && t < 300) {
        _root.__m1ProbeRead=true;
        var visible39=Key.isDown(39);
        var visible88=Key.isDown(88);
        var root39=_root.Key.isDown(39);
        var root88=_root.Key.isDown(88);
        _root.__m1ProbeRead=false;
        trace("LEBA_M1_SHADOW|t="+t+"|parent="+_root.일._currentframe+"|child="+_root.일.동작._currentframe+"|sub="+_root.일.동작.점프중._currentframe+"|sub_y="+_root.일.동작.점프중._y+"|move="+_root.일.이동._currentframe+"|px="+_root.일._x+"|py="+_root.일._y+"|face="+_root.bug1+"|held37="+(_root.__m1held[37]==true)+"|held39="+(_root.__m1held[39]==true)+"|held88="+(_root.__m1held[88]==true)+"|visible39="+visible39+"|visible88="+visible88+"|root39="+root39+"|root88="+root88+"|mock_calls="+previousCalls+"|mock39="+previous39+"|mock88="+previous88+"|mock_total="+_root.__m1MockTotal+"|global_unchanged="+(_global.Key==_root.__m1_originalKey && _global.Key.isDown==_root.__m1_originalIsDown));
        var shots="";
        for(var n in _root.일) {
            if(n.indexOf("대각총알") == 0) shots+=n+":"+_root.일[n]._currentframe+":"+_root.일[n]._x+":"+_root.일[n]._y+",";
        }
        if(shots!="") trace("LEBA_M1_SHADOW_SHOTS|t="+t+"|shots="+shots);
    }
    if(t == 300) {
        _root.__m1held={};
        if(_root.__m1_rootHadKey) _root.Key=_root.__m1_previousRootKey;
        else delete _root.Key;
        trace("LEBA_M1_SHADOW_DONE|t="+t+"|mock_total="+_root.__m1MockTotal+"|global_unchanged="+(_global.Key==_root.__m1_originalKey && _global.Key.isDown==_root.__m1_originalIsDown));
        this.fixture=undefined;
    }
};
