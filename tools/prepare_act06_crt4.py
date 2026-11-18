"""Prepare bounded CRT4 source facts and an explicit, selective import contract.

Only writes data/act06_crt4_{rules,import}.json. Original SWF/XML/AS and the
investigation snapshot are read-only. This is a data preparation tool, not an
AS interpreter, renderer, or author-resource migration.
"""
from __future__ import annotations
import hashlib
import importlib.util
import json
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

sys.dont_write_bytecode = True
PROJECT = Path(__file__).resolve().parents[1]
BASE = PROJECT.parent
INV = PROJECT / "artifacts/leba_act06_20261117/investigation"
IDENTITY = [1., 0., 0., 1., 0., 0.]


def load(name):
    return json.loads((INV / name).read_text(encoding="utf-8"))


S = load("crt4_source_symbols.json")
D = load("crt4_default_summary.json")
P = load("crt4_asset_plan.json")
W = load("crt4_callback_windows.json")["windows"]
TYPED = load("crt4_typed_rules.json")
_spec = importlib.util.spec_from_file_location("crt4_readonly", INV / "collect_crt4.py")
_reader = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_reader)


def ensure(ids):
    missing = set(map(int, ids)) - set(map(int, S))
    if missing:
        found = _reader.read(missing)
        if missing - set(found):
            raise ValueError(f"Missing original definitions: {missing - set(found)}")
        S.update({str(k): v for k, v in found.items()})


def refs(sid, frame=None):
    return [{k: x[k] for k in ("frame", "path", "sha256")}
            for x in S[str(sid)].get("scripts", []) if frame is None or x["frame"] == frame]


def script_order(ref):
    match=re.search(r"_(\d+)\.as$",ref["path"])
    return ("onClipEvent(load)"not in ref["path"],int(match[1])if match else 1)


def rows(sid, frame):
    return S[str(sid)].get("frames", {}).get(str(frame), [])


def clean(p):
    out = {k: p[k] for k in ("source_id", "depth", "name", "matrix", "ratio", "clipDepth") if k in p}
    out["matrix"] = out.get("matrix", IDENTITY)
    if p.get("color_transform"):
        out["color_transform"] = {k: v for k, v in p["color_transform"].items() if k != "type"}
    if p.get("filter_xml"):
        out["filters"] = [{"kind": e.get("type"), **{k: v for k, v in e.attrib.items() if k != "type"},
                           "children": [{"name": c.tag, **c.attrib} for c in e]} for e in ET.fromstring(p["filter_xml"])]
    return out


def placements(sid, ids=None):
    """Changed effective placements; source clocks do not advance by this table."""
    result, previous = [], None
    for f, rr in S[str(sid)].get("frames", {}).items():
        value = [clean(p) for p in rr if ids is None or p["source_id"] in ids]
        if value != previous:
            result.append({"source_frame": int(f), "placements": value})
            previous = value
    return result


def mul(a, b):
    return [a[0]*b[0]+a[2]*b[1], a[1]*b[0]+a[3]*b[1],
            a[0]*b[2]+a[2]*b[3], a[1]*b[2]+a[3]*b[3],
            a[0]*b[4]+a[2]*b[5]+a[4], a[1]*b[4]+a[3]*b[5]+a[5]]


def transform_rect(rect, m):
    x, y, w, h = rect
    pp = [(m[0]*a+m[2]*b+m[4], m[1]*a+m[3]*b+m[5]) for a, b in
          [(x,y),(x+w,y),(x,y+h),(x+w,y+h)]]
    lo = [min(p[i] for p in pp) for i in (0,1)]
    hi = [max(p[i] for p in pp) for i in (0,1)]
    return [lo[0], lo[1], hi[0]-lo[0], hi[1]-lo[1]]


def geometry_ids(seeds):
    pending, visited = set(seeds), set()
    while pending:
        ensure(pending)
        visited.update(pending)
        pending = {p["source_id"] for sid in pending for rr in S[str(sid)].get("frames", {}).values()
                   for p in rr} - visited


def shape_rects(sid, frame=1, matrix=None, trail=()):
    """Source shape bounds, including transparent collision shapes; never PNG bounds.

    Nested symbols use their source page 1 unless a caller supplies a separate
    child clock. Composite animated bounds are exported per source frame below.
    """
    if sid in trail:
        raise ValueError(f"Cyclic bounds graph {trail} -> {sid}")
    m = matrix or IDENTITY
    r = S[str(sid)]
    b = r.get("bounds", {}).get("shapeBounds") or r.get("bounds", {}).get("startBounds")
    if b:
        rect = [int(b["Xmin"])/20, int(b["Ymin"])/20,
                (int(b["Xmax"])-int(b["Xmin"]))/20, (int(b["Ymax"])-int(b["Ymin"]))/20]
        return [{"shape_id": sid, "shape_rect": rect, "matrix": m,
                 "rect": transform_rect(rect, m), "bounds_source": "original XML shapeBounds; twips / 20"}]
    result = []
    for p in rows(sid, frame):
        result += shape_rects(p["source_id"], 1, mul(m, p.get("matrix", IDENTITY)), trail+(sid,))
    return result


def body_geometry():
    parent = {}
    clip_ids = set()
    for f in range(146, 177):
        rr = [p for p in rows(6732, f) if p.get("name") in ("몸빵", "중력몸빵", "타격")]
        parent[str(f)] = {p["name"]: clean(p) for p in rr}
        clip_ids.update(p["source_id"] for p in rr if p.get("name") != "타격")
    geometry_ids(clip_ids)
    clips = {}
    for sid in sorted(clip_ids):
        stop = sorted({x["frame"] for x in S[str(sid)]["scripts"] if re.search(r"(?<!\w)stop\(\)", x["text"])})
        clips[str(sid)] = {"source_id": sid, "stop_frames": stop,
            "rects_by_source_frame": {f: [x["rect"] for x in shape_rects(sid, int(f))]
                                      for f in S[str(sid)]["frames"]},
            "placements_already_in_rects": "inner shape placements only; parent6732 body matrix applies once"}
    return {"parents": parent, "clips": clips, "dynamic": P["body_dynamic"],
            "absence_is_empty": True, "player_hit_fx": {"animation": "player_hit_fx", "source_id": 4689,
                "baked_parent_transform": True, "runtime_scale": [1,1],
                "verification": "6732 parent14/169/170 same basis [.3622589,0,0,.3516693], no CXFORM, byte-equal original glow filter; only translation differs",
                "parents": {str(f): clean(next(p for p in rows(6732, f) if p.get("name") == "타격"))
                            for f in (169,170)}}}


def simple_audio(sid):
    out = []
    for i, a in enumerate(S[str(sid)].get("start_sounds", [])):
        info = dict(a["info"])
        root = ET.fromstring(a["sound_info_xml"])
        info["envelopes"] = [dict(e.attrib) for e in root.iter("item")]
        out.append({"source_frame": a["frame"], "sound_id": a["sound_id"], "sound_info": info,
                    "kind": "start_sound", "instance_clock": sid,
                    "alias": f"crt4_source_{sid}_sound_{i+1}"})
    return out


def default_rule(w):
    """Finite CRT4 callback families. This output is consumed by local adapters.

    Conditions remain explanatory references, never an AS expression evaluator.
    Marker observers intentionally are not a fixed total attack damage.
    """
    sid, h, lo, dep = (w[k] for k in ("owner_source_id","helper_source_id","from_source_frame","depth"))
    text = "\n".join((BASE/x["path"]).read_text(encoding="utf-8") for x in w["scripts"])
    result = {"scope": "source_helper_instance", "once_per_action": False,
              "source_targets": [1,2,3,4,5], "observer_requires_this_contact": False}
    if 'attachMovie("암속"' in text and not "중력" in text:
        return dict(result, kind="dark_hit_fx", contact_bodies=["normal","super","frozen"],
                    source_id=578, local_depth_initial=0, local_depth_increment=False, helper_seek=2)
    if h in (439,224) and "중력" in text:
        gs = re.findall(r"중력\s*=\s*(-?[0-9.]+)", text)
        result.update(kind="launch", gravity=float(gs[0]), gacc_delta=.1,
                      contact_bodies=["normal"], frozen_seek=2, super_seek=2, helper_seek=2,
                      reset_marker="공중.타격.gotoAndPlay(2)" in text,
                      marker_seek=2 if "공중.타격.gotoAndPlay(2)" in text else 0)
        if re.search(r"행동몸빵.hitTest\(this\)\s*\|\|[^\n]*슈퍼아머", text):
            result["contact_bodies"].append("super")
        if "mr < 3" in text:
            result.update(contact_limit=3, counter="mr_by_target", counter_initial=0, counter_scope="helper_instance")
        # These callback sets contain independent marker observers, in source record order.
        observers=[]
        for script in sorted(w["scripts"],key=script_order):
            t=(BASE/script["path"]).read_text(encoding="utf-8")
            for hit in re.finditer(r"if\(([^\n]+)\)\s*\{\s*_root\.적\d*\.hp\s*-=\s*([0-9.]+)",t):
                if "hitTest" in hit[1]:continue
                target=re.search(r"_root\.적(\d*)",hit[1]);target=int(target[1] or 1) if target else 0
                state="air_or_frozen" if "공중"in hit[1] and "얼음"in hit[1] else "air" if "공중"in hit[1] else "frozen"
                observers.append({"target":target,"state":state,"observer_marker_frame":2,
                                  "observer_damage":float(hit[2]),"source":script["path"]})
        result["observers"] = observers
        if sid==1153 and lo==1: result["status"]={"clone_selector_next_frame":True,"source_id":3971}
        if sid==1153 and lo==5: result["frozen_to_normal_source_frame"]=2
        if sid==906:
            result.update(host="player_root_only", observer_marker_frame=2,
                          observer_damage={"air":50,"frozen":25} if lo==4 else {"air_or_frozen":700},
                          marker_bonus_per_active_flag=0 if lo==4 else 75,
                          bonus_flags=[] if lo==4 else ["kaz","bremen","saya","rhasa","ghostwalk","kalla"])
        return result
    if sid==6446 and lo==115:
        return dict(result,kind="freeze",contact_bodies=["normal","frozen"],
                    contact_limit_by_body={"normal":None,"frozen":3},counter="mr_by_target",counter_initial=0,
                    direct_damage=20,status="frozen",frozen_seek=2,
                    precedence="normal OR (frozen AND mr < 3); mr increments for either branch")
    if h==6443:
        if (sid==6446 and lo==113) or (sid==6506 and lo==8):
            return dict(result,kind="ground",contact_bodies=["normal","super","frozen"],gravity=0,gacc=0,
                        enemy_y="source_floor_y",outer_frame=1,slow_seek=1 if sid==6506 else None)
        return dict(result,kind="ghostslash_mark",contact_bodies=["frozen"] if lo==12 else ["normal","super","frozen"],
                    normal_state_label="kk",normal_marker_seek=8,status="ghostslash_pending")
    if h==6486:return dict(result,kind="apply_observer_status",contact_bodies=["normal","super","frozen"],
                          status_source_id=3951,status_seek=2,status_clock="per_target_instance")
    if h==815:return dict(result,kind="freeze",contact_bodies=["normal","frozen"],status="frozen",frozen_seek=2,direct_damage=30)
    if h==1119:return dict(result,kind="spawn_mummy",contact_bodies=["normal","frozen"],source_id=978,
                           spawn_at="target_xy",global_i_increment=True,
                           mirror_bug="after increment, random<=.5 writes next instance name")
    if sid==316:return dict(result,kind="field_marker_observer",requires_player_body_overlap=True,
                           observer_marker_frame=2,observer_damage={"air":10,"frozen":10,"ghostslash19":30})
    if sid==956:return dict(result,kind="field_marker_observer",requires_player_body_overlap=False,
                           observer_marker_frame=2,observer_damage={"air":21,"frozen":21,"ghostslash18":150})
    if sid==4318 and h==1729:return dict(result,kind="persistent_hud_observer",air_targets=[1,2,4,4,5],air_damage=4,
                            ghostslash_targets=[1,2,3,4,5],ghostslash_frame=19,ghostslash_damage=15)
    if sid==6458 and h==6448:return dict(result,kind="marker_observer",observer_marker_frame=2,observer_damage={"air":25,"frozen":25})
    if sid==6541 and h==1234:return dict(result,kind="grab_select",contact_bodies=["normal","super"],
                                      source_order=[1,2,3,4,5],target_source_frame=17,existing_zab_nonzero_also_seeks=True)
    if sid==6541 and h==5652:return dict(result,kind="grab_anchor",gravity_delta=-2,gacc_delta=.1,
        target="zab",formula_x="player_x + (action_local_x + helper_local_x) * facing",
        formula_y="player_y + action_local_y + helper_local_y",uses_actor_parent_scale=False)
    if sid==978:return dict(result,kind="mummy_contact" if lo==19 else "mummy_follow_bleed",
                           contact_bodies=["normal","frozen"],contact_seek=20 if lo==19 else None,
                           bleed_visual_frame=1,observer_damage=1 if lo==27 else 0,observer_targets=[1,2,3,4,5])
    return dict(result,kind="control",control_owner=sid,control_helper=h,
                note="Input/hold/placement control in actions.controls; this is not a damage window")


def build_windows():
    # The original main/world audit omitted the independent jump child6528.
    # Its ordinary X has one actual callback-bearing instance, not frames2..11.
    air_scripts=[x for x in refs(6528,4)if "/PlaceObject2_439_45/"in x["path"]]
    air_frames=[int(f)for f,rr in S["6528"]["frames"].items()
                if any(p["source_id"]==439 and p["depth"]==45 for p in rr)]
    assert air_frames==[4,5,6] and len(air_scripts)==26
    air_placement=next(p for p in rows(6528,4)if p["source_id"]==439 and p["depth"]==45)
    windows=W+[{"owner_source_id":6528,"helper_source_id":439,"depth":45,
        "from_source_frame":4,"until_source_frame":6,"collision_present":True,
        "scripts":air_scripts,"placement_track":[dict(air_placement,source_frame=4)]}]
    colliders={w["helper_source_id"] for w in windows if w["collision_present"]}
    # Character costume child listeners are controls rather than collision bodies.
    colliders -= {6392,6418,6114,4051,4937,5417,6528}
    geometry_ids(colliders)
    result=[]
    for w in windows:
        r={"source_id":w["owner_source_id"],"helper_source_id":w["helper_source_id"],"source_depth":w["depth"],
           "from":w["from_source_frame"],"until":w["until_source_frame"],"source":sorted(w["scripts"],key=script_order),
           "placement_track":[clean(x)|{"source_frame":x["source_frame"]} for x in w["placement_track"]],
           "default_rule":default_rule(w),"rect_space":"owner source local; actor parent matrix not yet applied"}
        r["kind"]="crt4_"+r["default_rule"]["kind"]
        r["local_rects_by_source_frame"]={}
        if w["helper_source_id"] in colliders:
            for f in range(r["from"],r["until"]+1):
                pp=next((p for p in rows(r["source_id"],f) if p["depth"]==r["source_depth"] and p["source_id"]==r["helper_source_id"]),None)
                if pp:
                    r["local_rects_by_source_frame"][str(f)]=[x["rect"] for x in shape_rects(r["helper_source_id"],1,pp.get("matrix",IDENTITY))]
            r["local_rects"]=r["local_rects_by_source_frame"].get(str(r["from"]),[])
        result.append(r)
    return result


NAME_MAP={"idle":"idle","x1":"basic","x2":"basic2","x3_source_unconfirmed_default_reach":"basic3",
 "a":"skill_a","s":"skill_s","q":"skill_q","w":"skill_w","e":"skill_e","d_field":"skill_d",
 "f_field":"skill_f","g_field":"skill_g","r":"skill_r","h_field":"skill_h","z":"skill_z",
 "t_start":"skill_t","t_finish":"t_finish","kalla_x":"kalla_basic","jump":"jump","backstep":"backstep",
 "hurt":"hit","air_hurt":"knockdown","air_grab":"air_grab","landing_damage":"landing_damage",
 "fallen":"fallen","dead":"dead","v":"skill_v","y":"skill_y"}
SELECTORS={24:1,46:1,47:1,56:1,3774:1,3815:1,6386:1,6392:1,6412:1,5191:3,5201:3}


def event(frame,kind,**kw):return dict(frame=frame,kind="crt4_"+kind,**kw)


def build_actions(windows):
    out={}
    for old,new in NAME_MAP.items():
        if new in ("air_grab","landing_damage"):
            continue  # Unused route; no119-frame grab atlas for an unproved default input.
        r=D["actions"][old]; sid=r["source_id"]
        seq=[f for lo,hi in r["curated_render_ranges"] for f in range(lo,hi+1)]
        if new=="idle":seq=list(range(1,16))
        if new=="fallen":seq=[1]
        key="crt4_cast" if sid==6507 else "crt4_"+new
        out[new]={"source_id":sid,"source_parent":r["parent_frame"],"parent_matrix":r["parent_placement"]["matrix"],
            "animation":key,"sequence":seq,"input":"","cost":0,"required_mp":0,"cubes":0,"cooldown_ticks":0,
            "allowed_states":[],"source_allowed_parent_frames":[],"source":refs(sid),"source_selected":True,
            "controls":[],"events":[],"windows":[x for x in windows if x["source_id"]==sid and x["default_rule"]["kind"]!="control"],
            "loop":new=="idle","hold":new in ("fallen","dead"),"next_action":"idle"}
        if new in ("basic3","air_grab","landing_damage"):
            out[new]["source_selected"]=False
            out[new]["selection_note"]="Source definition retained; no unverified default input route is invented"
    out["move"]={**out["idle"],"source_id":6393,"source_parent":146,"parent_matrix":[1,0,0,1,12.6,20.2],
        "animation":"crt4_move","sequence":list(range(1,13)),"source":refs(6393),"loop":True,
        "matrix_chain":[clean(next(p for p in rows(6732,146)if p["source_id"]==6406)),
                        clean(next(p for p in rows(6406,16)if p["source_id"]==6405)),
                        clean(next(p for p in rows(6405,1)if p["source_id"]==6393))]}
    parent_actions={r["source_parent"]:k for k,r in out.items() if k!="move"}
    for key,slot in D["slots"].items():
        name="skill_"+key.lower();r=out[name]
        allowed=[parent_actions[f] for f in slot["allowed_parent_frames"] if f in parent_actions]
        if 146 in slot["allowed_parent_frames"]:allowed.insert(1,"move")
        r.update(input="skill" if key=="D" else name,cost=slot["mp"],required_mp=slot["mp"],cubes=slot["cubes"],
                 cooldown_ticks=slot["actual_source_frames"]-1,cooldown_key="skill" if key=="D" else name,
                 allowed_states=allowed,source_allowed_parent_frames=slot["allowed_parent_frames"],slot_source_id=slot["source_id"],
                 ready_source_frame=slot["ready_source_frame"],source_entry=[{k:x[k]for k in ("frame","path","sha256")}for x in slot["entry_scripts"]])
    for k in ("basic","basic2","basic3"):out[k]["input"]="attack"
    out["basic"]["allowed_states"]=["idle","move"]
    out["jump"].update(input="jump",allowed_states=["idle","move"])
    out["backstep"].update(input="backstep",allowed_states=["idle","move","basic","basic2","basic3"])
    out["t_finish"].update(input="skill_t",cost=8,required_mp=8,cubes=0,allowed_states=["idle","move","kalla_basic"],
                           source_allowed_parent_frames=[146,166])
    out["basic"]["controls"]=[{"event":"key_down","key":"X","at":9,"parent_goto_play":151,"kind":"play_source_parent"}]
    out["basic2"]["controls"]=[{"event":"key_down","key":"X","at":10,"parent_goto_play":151,"kind":"play_source_parent"}]
    out["skill_a"]["controls"]=[
      {"event":"enter_frame","at":4,"held_key":"A","held":"play","released_seek":27},
      {"event":"do_action","at":15,"seek":26,"play":False},
      {"event":"enter_frame","at":26,"held_key":"A","held_seek":26,"released_seek":49},
      {"event":"load","at":57,"branch_field":"ghost","source_seek_by_value":{"1":58,"2":86,"3":114}},
      {"event":"do_action","at_any":[48,76,104,132],"parent_goto_stop":146}]
    out["skill_s"]["controls"]=[{"event":"key_down","key":"S","at":5,"seek":11},
      {"event":"key_down","key":"S","at":17,"seek":24},{"event":"do_action","at_any":[10,23,40],"parent_goto_stop":146}]
    out["skill_e"]["controls"]=[{"event":"do_action","at":28,"held_key":"E","released":"mark_all_then_damage350_in_order_5_to_1_and_return146","held":"continue"},
      {"event":"do_action","at":45,"operation":"marked_targets_damage350_in_order_1_to_5"},
      {"event":"enter_frame","from":45,"until":64,"operation":"air_targets_attract_8_5_two_sequential_comparisons"}]
    out["skill_r"]["controls"]=[{"event":"key_down","key":"C","from":7,"until":86,"parent_goto_stop":146},
      {"event":"enter_frame","from":7,"until":86,"operation":"k_increment_spawn_tombstone_when_gt2_reset0"}]
    out["skill_t"]["controls"]=[{"event":"entry","requires_flag":"kalla","value":0}]
    out["t_finish"]["controls"]=[{"event":"entry","requires_component_frame":12,"component":6384,
      "end_kalla_unless_blaze":5,"component_seek":13}]
    out["skill_y"]["controls"]=[{"event":"entry","slot_ready":291,"slot_seek_stop":2},
      {"event":"world_906_frame40","slot_seek_play":2,"cheat_slot_stop":291}]
    out["skill_v"]["controls"]=[{"event":"do_action","at":16,"parent_goto_stop":146},
      {"event":"contact","from":5,"until":7,"seek":17},{"event":"do_action","at":66,"set_zab":0}]
    out["skill_v"]["nested_audio"]=[{"identifier":"src5732_depth35_at29","parent_source_id":6541,
      "source_id":5732,"source_depth":35,"from_frame":29,"until_frame":78,"entry_frame":1,
      "stop_source_frame":40,"source_total_frames":83,"audio_alias_prefix":"crt4_source_5732",
      "source_matrix":[1.1841431,0,0,1.1841431,153.75,2.1],
      "source_note":"displaylist persists through79, but source79 returns parent146; independent child sound12, not parent40"}]
    out["jump"]["controls"]=[{"event":"held_X_child6528","at":1,"seek_if_kalla":13,"seek_otherwise":2},
      {"event":"do_action","at":30,"stop_parent":True,"return146_if_child_below":13}]
    out["backstep"]["controls"]=[{"event":"key_down","key":"X","requires_kalla":1,"child_frame":1,"child_seek":2}]
    for k,sid in (("skill_d",316),("skill_f",956),("skill_g",818),("skill_h",1121)):
        out[k]["events"]=[event(7,"spawn_field",source_id=sid,x_offset=100,y_offset=0,global_i_increment=True)]
    out["skill_w"]["events"]=[event(7,"component_seek",source_id=6360,source_frame=2)]
    out["skill_t"]["events"]=[event(7,"component_seek",source_id=6384,source_frame=2)]
    out["kalla_basic"]["events"]=[event(3,"spawn_clone",source_id=1326)]
    out["skill_e"]["events"]=[event(6,"cutin",source_frame=130),event(8,"ghostwalk_hide_and_map_dark"),
       event(12,"random_targets_reset"),event(28,"ghostslash_release"),event(45,"ghostslash_finish"),event(65,"ghostwalk_restore")]
    out["skill_y"]["events"]=[event(2,"cutin",source_frame=130),event(21,"spawn_swamp",source_id=944,y_offset=-80,scale_y=2,depth_initial=-16300)]
    out["hit"]["events"]=[event(2,"player_hit_marker",source_frame=2)]
    out["dead"]["events"]=[event(1,"clear_persistent_states"),event(25,"stop_all_sounds")]
    # All displacement rows are source ticks, not arbitrary physics/render frames.
    movement={"skill_a":[[59,61,15],[61,63,10],[64,66,2],[87,89,15],[90,92,10],[93,95,2],[115,116,15],[117,119,10],[120,122,2]],
      "skill_s":[[3,7,4],[11,16,4],[26,33,4]],"skill_z":[[5,7,5],[8,10,2]],"t_finish":[[12,29,3]],"backstep":[[1,11,-5]]}
    for k,rr in movement.items():out[k]["source_displacement"]=[{"from":a,"until":b,"dx_per_tick":v,"facing_relative":True}for a,b,v in rr]
    for action in out.values():
        for window in action["windows"]:
            window["default_selected"]=any(window["from"]<=f<=window["until"] for f in action["sequence"])
    return out


def animation_plan(actions):
    animations={}; removes={6446:[6418],6506:[6505],6530:[6528,5417],6532:[6531]}
    def add(key,sid,ff,parent=None,pf=None,depth=None,remove=(),loop=False,matrix=None,is_main=False):
        pp=next((p for p in rows(parent,pf)if p["source_id"]==sid and (depth is None or p["depth"]==depth)),None)if parent else None
        mm=matrix or (pp.get("matrix",IDENTITY)if pp else IDENTITY)
        animations[key]={"source_id":sid,"frames":list(ff),"loop":loop,"parent_id":parent,"parent_source_frame":pf,
          "parent_depth":depth,"parent_matrix":mm,"effective_parent_matrix":mm,"is_main":is_main,
          "parent_placement":clean(pp)if pp else None,
          "remove_child_ids":list(remove),"selector_pages":{str(k):v for k,v in SELECTORS.items()},
          "offset":mm[4:6]if is_main else [0,0],"basis":mm[:4]if is_main else [1,0,0,1],"source":refs(sid),
          "pivot_contract":"Main: effective parent translation baked in atlas pivot, diagonal basis in PARENT_SCALES once. Part: source local pixels; full parent chain applied by runtime; filter wrapper bake needs explicit inverse metadata."}
    for name,r in actions.items():
        if r["animation"]in animations:continue
        add(r["animation"],r["source_id"],r["sequence"],6732,r["source_parent"],41,removes.get(r["source_id"],()),name in ("idle","move"),r["parent_matrix"],True)
    parts=[
      ("a_charge",6418,6,6446,26,104,[],False),
      ("e_dark_local",6505,10,6506,45,28,[],False),
      ("jump_attack",6528,21,6530,4,1,[],False),
      ("backstep_attack",6531,9,6532,1,1,[],False),
      ("ghostwalk",6360,20,6732,146,7,[6359],False),
      ("ghost_move_timer",6395,35,6397,4,1,[],False),
      ("ghost_move_exit_fx",6402,8,6404,1,24,[],False),
      ("kalla",6384,21,6732,146,33,[6380,6378],False),
      ("move_body",6393,12,None,None,None,[],True),
      ("kalla_body",6378,8,6380,1,1,[],True),
      ("field_d_base",313,1,316,9,1,[312],False),
      ("field_d_loop",312,12,313,1,3,[],True),
      ("field_f_base",954,1,956,9,1,[953],False),
      ("field_f_loop",953,13,954,1,3,[],True),
      ("field_g_base",816,1,818,9,1,[813,815],False),
      ("field_g_loop",813,12,816,1,3,[],True),
      ("field_h_base",1120,1,1121,10,1,[1117,1119],False),
      ("field_h_loop",1117,13,1120,1,3,[],True),
      ("mummy_birth",556,10,978,1,1,[],False),
      ("tombstone",1273,31,None,None,None,[],False),
      ("y_swamp_cell",932,S['932']['actual_frames'],944,1,1,[],False),
      ("y_wisp",942,21,943,1,1,[],True),
      ("y_beast",906,40,907,1,2,[],False),
      ("dark_hit",578,8,None,None,None,[],False),
      ("clone_flight",1149,9,1326,1,1,[],True),
      ("clone_status",1149,9,3968,1,1,[],True),
      ("ghostwalk_loop",6346,6,6356,1,9,[],True),
      ("clone_diagonal_flight",1149,9,1154,1,1,[],True),
      ("clone_hit",1153,8,1326,2,1,[],False),
      ("clone_diagonal_hit",1153,8,1154,2,1,[],False),
      ("ghostslash_status",3962,20,3963,2,2,[],False),
    ]
    for key,sid,n,par,pf,dep,rm,loop in parts:add("crt4_"+key,sid,range(1,n+1),par,pf,dep,rm,loop)
    # 861 is the original clipDepth30 mask, never a painted black background.
    # The 906 atlas must be rendered inside the original907 mask wrapper. This
    # bakes its full placement, so runtime must not apply that translation twice.
    animations["crt4_y_beast"].update(mask_parent=907,mask_parent_source_frame=1,
        mask_child_depth=2,mask_shape_id=861,baked_full_parent_matrix=[1,0,0,1,-59.3,-99.8],
        pivot_contract="Original907/1 mask wrapper: 861 depth1 clips through30; child906 depth2 full matrix[1,0,0,1,-59.3,-99.8] is baked. Runtime applies world907 transform only, or author child matrix times inverse baked matrix. Never draw861 as black pixels or render unmasked906.")
    # No animated child in these parents: unique display states are safe sparse samples.
    sparse={"mummy":978,"q_status":3951}
    sparse_maps={}
    for name,sid in sparse.items():
        states={}; mapping={}; ff=[]
        remove=[556]if sid==978 else []
        for f,rr in S[str(sid)]["frames"].items():
            # Ratio matters for MorphShape; clipActions do not affect raster identity.
            signature=json.dumps([clean(x)for x in rr if x["source_id"]not in remove],sort_keys=True)
            if signature not in states:states[signature]=int(f);ff.append(int(f))
            mapping[f]=states[signature]
        add("crt4_"+name,sid,ff,remove=remove)
        sparse_maps["crt4_"+name]={"source_frame_to_sample":mapping,"source_clock_frames":S[str(sid)]["actual_frames"]}
    add("hud_crt4_cutin",6835,range(130,162),6917,1,None)
    return animations,sparse_maps


def components():
    ids=[316,313,956,954,818,816,1121,1120,978,1273,6360,6359,6384,6380,1326,1154,1153,
         3971,3968,3969,3970,3963,3962,3966,944,932,943,942,907,906,578,3951,4318,6397,6395,6404,6402,6418,6505,6528,6531,556,6405,5417]
    out={}
    for sid in ids:
        r=S[str(sid)]
        stop=sorted({x['frame']for x in r['scripts']if 'DoAction'in x['path'] and re.search(r'(?<!\w)stop\(\)',x['text'])})
        out[str(sid)]={"source_id":sid,"source_frame_count":r.get("actual_frames",1),"stop_source_frames":stop,
          "placement_tracks":placements(sid),"source":refs(sid),"sound_events":simple_audio(sid),
          "births":[dict(frame=x["frame"],**clean(x))for x in r.get("placements",[])],
          "clock_contract":"independent source25Hz; held parent does not hold child; source re-placement may recreate child"}
    out["316"].update(flag="kaz",flag_on_frame=2,ghost_select_frame=9,ghost_value=1,clear_frame=540)
    out["956"].update(flag="bremen",flag_on_frame=9,ghost_select_frame=9,ghost_value=2,clear_frame=544)
    out["818"].update(flag="saya",flag_on_frame=9,ghost_select_frame=9,ghost_value=3,clear_frame=271)
    out["1121"].update(flag="rhasa",flag_on_frame=10,clear_frame=426)
    out["6360"].update(flag="ghostwalk",flag_on_frame=13,flag_clear_frame=1,held_frames=[18,19,20],timer_source=6359,timer_frames=545,
      timer_preserved_across_parent_pages=[18,19,20],timer_preservation_source="same depth13 effective instance remains on18/19/20; transitions do not create a new6359")
    out["6360"]["held_visual_loop"]={"source_id":6346,"animation":"crt4_ghostwalk_loop",
        "frames":6,"loop":True,"source_scripts":[],
        "parent_tracks":placements(6360,{6356,6346}),"container_source_id":6356,
        "container_inner_placement":clean(next(p for p in rows(6356,1)if p["source_id"]==6346)),
        "active_parent_frames":[18,19,20],
        "alpha_mult_by_parent_frame":{"18":128,"19":256,"20":256},
        "filters":[],"clock":"Independent6346 natural6-loop; held6360 does not pause it.18/19 retain6356,20 replaces it with direct6346.",
        "matrix_contract":"Apply6360 actor placement, then6356 ancestor if present, then6346 local matrix exactly once; atlas is6346-local."}
    out["6528"]["ordinary_air_x"]={"entry":{"parent_source_id":6530,"parent_source_frame":4,
        "held_key":"X","child_at":1,"kalla_equals":0,"seek_play":2},
        "callback_window":{"from":4,"until":6,"helper_source_id":439,"depth":45},
        "normal_gravity":-6,"gacc_delta":.1,"explicit_air_marker_seek":False,
        "local_damage_observers":[],"dark_fx_spawn":False,"frozen_inner_seek":2,"super_seek":2,
        "helper_seek_on_frozen_or_super":2,
        "nested_directional_proxy":{"source_frame":4,"placement":clean(next(p for p in rows(6528,4)if p.get("name")=="왼대각")),
            "observed_by_root_common_slash":False,
            "reason":"Root observers address actor.action.left_diagonal, not actor.action.jump_child.left_diagonal; separate5417 is the actual direct proxy."}}
    out["5417"].update(visible_png_required=False,source_frame_count=13,stop_source_frames=[1],
        terminal_goto={"source_frame":13,"goto_play":1},
        input={"event":"key_down","held_key":"X","only_at_child_frame":1,"seek_play":2,
            "source":next(x for x in refs(6530,4)if "/PlaceObject2_5417_55/"in x["path"])},
        parent_placement_tracks=placements(6530,{5417}),
        local_rects_by_source_frame={str(f):[x["rect"]for x in shape_rects(5417,f)]for f in range(1,14)},
        clock_note="Independent keyDown proxy; do not synchronize with6528 held-X polling. Only5417 source5 contains transparent439; actor parent main-frame placement changes independently.")
    out["6405"].update(selector=True,default_page=1,ghost_entry_page=2,ghost_exit_page=3,
      body_page_by_source_frame={"1":1,"2":2,"3":1},
      control="On entry page1 if ghostwalk flag1: outer6360->19, this->2. 6395 child35 moves this to3; page3 outer6360->18.")
    out["6384"].update(flag="kalla",flag_on_frame=3,flag_clear_frame=13,held_frame=12,timer_source=6380,timer_frames=574)
    out["943"].update(hold_frame=35,timer_initial=0,timer_bonus_per_active_flag=8,timer_threshold=40,
      timer_flags=["kaz","bremen","saya","rhasa","ghostwalk","kalla"],timer_increment_per_callback=1,
      timer_release_seek=38,beast_spawn_source_frame=65,beast_source_id=907,beast_y_offset=100,beast_scale=[1.5,1.5])
    mask=next(p for p in rows(907,1)if p["source_id"]==861)
    out["907"]["mask"]={"source_id":861,"source_parent":907,"source_frame":1,
        "depth":1,"clip_depth":int(mask["clipDepth"]),"clipped_depth_range":[2,int(mask["clipDepth"])],
        "child_source_id":906,"child_depth":2,"matrix":mask.get("matrix",IDENTITY),
        "rect":[-484.5,-366.45,899.5,430.15],
        "polygon":[[415,-366.45],[415,63.7],[-484.5,63.7],[-484.5,-366.45]],
        "draw_as_visible_fill":False,"fill_rule":"evenodd","stroke":"none",
        "geometry_source":"res/structure/game.xml DefineShape861 and res/shapes/861.svg original path; not PNG bounds",
        "source_shape_sha256":hashlib.sha256((BASE/"res/shapes/861.svg").read_bytes()).hexdigest(),
        "correction":"Earlier black-background interpretation omitted clipDepth30; original opaque fill defines coverage only."}
    out["942"]["screen_displacements"]=[{"frame":1,"dx":1},{"frame":3,"dx":-2,"dy":1},
      {"frame":5,"set_x":0,"dy":-2},{"frame":7,"set_y":0},{"frame":9,"dx":1},
      {"frame":11,"dx":-2,"dy":1},{"frame":13,"set_x":0,"dy":-2},{"frame":15,"set_y":0},{"frame":16,"set_y":0}]
    out["3962"].update(capture_facings_frame=16,launch_frame=20,marked_normal_marker=8,
      gravity=-8,gacc_delta=.1,air_marker_seek=2,timer_interval_ms=10,timer_timeout_ms=1000,
      timer_key="flyInt",timer_callback="all_air_targets_x_minus_0_05_times_captured_face_percent",
      timer_scope="shared root.flyInt; each status has its own timeline; old timeout clears CURRENT shared ID",
      timer_guard_player_parent_not=175,clear_old_interval=True,clear_zab=True)
    out["3951"].update(active_from=9,active_until=293,air_marker_frame=2,air_targets=[1,2,7,7,5],air_damage=7,
      ghostslash_frame=19,ghostslash_targets=[1,2,3,7,5],ghostslash_damage=35,
      observer_scope="Each applied target status owns a separate GLOBAL target observer set; literal source typos retained")
    out["4318"].update(active_from=1,active_until=278,air_marker_frame=2,air_targets=[1,2,4,4,5],air_damage=4,
      ghostslash_frame=19,ghostslash_targets=[1,2,3,4,5],ghostslash_damage=15,
      observer_scope="one persistent HUD slot instance; not an attack-owned local bonus")
    for sid,damages in [(3968,[27]*5),(3969,[23,25,24,23,18]),(3970,[23]*5)]:
        out[str(sid)]["damage_events"]=[{"frame":f,"damage":v,"scope":"owning_enemy", "spawn_fx":578,
            "fx_depth":"current_root_i_without_increment"}for f,v in zip([29,56,82,108,135],damages)]
    return out


def named_common_slash(actions):
    """Existing root enemy observers, distinct from each attack's hit callbacks."""
    def source_ref(path):
        return {"path":path,"sha256":hashlib.sha256((BASE/path).read_bytes()).hexdigest()}
    names={"가로":"horizontal","왼대각":"left_diagonal","오른대각":"right_diagonal"}
    action_proxies={}
    for key,action in actions.items():
        selected=[]
        for f in action["sequence"]:
            for p in rows(action["source_id"],f):
                if p.get("name")not in names:continue
                r={"source_frame":f,"name":p["name"],"kind":names[p["name"]],"placement":clean(p)}
                if p["source_id"]==5417:
                    r.update(independent_clock_source_id=5417,active_child_source_frame=5,
                        local_rects=[x["rect"]for x in shape_rects(5417,5)])
                else:r["local_rects"]=[x["rect"]for x in shape_rects(p["source_id"],1)]
                selected.append(r)
        if selected:action_proxies[key]={"source_id":action["source_id"],"source_selected":action["source_selected"],
            "rect_space":"proxy-local; apply placement then main action/actor matrix once","proxies":selected}
    observers=[]
    for stage,dirs,first in [(2,["PlaceObject3_4030_222"],43),
        (4,["PlaceObject3_4030_224","PlaceObject3_4030_705","PlaceObject3_4030_1142","PlaceObject3_4030_1389"],43),
        (6,["PlaceObject3_7176_458"],69),(9,["PlaceObject3_7437_294"],61),(41,["PlaceObject3_4030_111"],37)]:
        for directory in dirs:
            prefix=f"res/scripts/frame_{stage}/{directory}/"
            paths=[prefix+f"CLIPACTIONRECORD onClipEvent(enterFrame)_{first+i}.as"for i in range(3)]
            for path in paths:
                text=(BASE/path).read_text(encoding="utf-8")
                assert "this.속.행동몸빵"in text and "_root.일.동작."in text
            load=prefix+"CLIPACTIONRECORD onClipEvent(load)_3.as"
            assert all(f"var {name} = {v}"in (BASE/load).read_text(encoding="utf-8")for name,v in [("o",1),("p",2),("l",3)])
            observers.append({"root_source_frame":stage,"enemy_placement":directory,
                "source":{name:source_ref(path)for name,path in zip(["horizontal","left_diagonal","right_diagonal"],paths)},
                "load_source":source_ref(load)})
    return {"owner":"each existing root enemy ClipAction instance","source_targets":"this enemy normal body only",
        "source_path":"_root.일.동작.<name>","source_hp_guard":False,
        "attach_position":"enemy world x,y","attach_scale":"original linkage default100%; not actor scale",
        "depths":{"horizontal":1,"left_diagonal":2,"right_diagonal":3},"depth_increment":False,
        "replacement":"Repeated callbacks attach at the same root depth; no per-action once guard exists.",
        "orientation":{"horizontal":{"always_source_id":1489},
            "left_diagonal":{"player_x_lte_enemy":1481,"player_x_gte_enemy":1496},
            "right_diagonal":{"player_x_lte_enemy":1496,"player_x_gte_enemy":1481},
            "equality":"Both independent source ifs execute at equal x, second attach replaces same depth."},
        "sound":{"character_id":4,"linkage":"도","sound_id":5,"on_fx_source_frame":1,
            "source":[source_ref(next((BASE/"res/scripts").glob(f"DefineSprite_{sid}_*/frame_1/DoAction.as")).relative_to(BASE).as_posix())for sid in (1481,1489,1496)],
            "export_source":"res/structure/game.xml ExportAssets 도->5; CRT3 광검->4 is a different branch"},
        "actions":action_proxies,"root_observers":observers,
        "not_damage":"These callbacks attach FX/sound; they do not replace attack gravity/marker/damage callbacks.",
        "validation":"Original AS paths, default selected action frames and XML shape bounds; no natural input phase claim."}


def main():
    ensure({942,3951,305,304,973,975,974,6485,1729,3947,3949,3966,5732,556,5417,6346})
    windows=build_windows()
    actions=build_actions(windows)
    animations,sparse=animation_plan(actions)
    comp=components()
    common_slash=named_common_slash(actions)
    body=body_geometry()
    audio={str(sid):simple_audio(sid) for sid in sorted(set(r["source_id"]for r in actions.values())|set(map(int,comp))|{5732})}
    audio={k:v for k,v in audio.items()if v}
    validation={"source_hashes_checked":0,"errors":[]}
    seen=set()
    for row in S.values():
        for ref in row.get("scripts",[]):
            if ref["path"]in seen:continue
            seen.add(ref["path"])
            actual=hashlib.sha256((BASE/ref["path"]).read_bytes()).hexdigest()
            if actual!=ref["sha256"]:validation["errors"].append("source changed: "+ref["path"])
            validation["source_hashes_checked"]+=1
    for key,spec in animations.items():
        if any(f<1 or f>S[str(spec["source_id"])]["actual_frames"]for f in spec["frames"]):validation["errors"].append("invalid animation selection: "+key)
    if validation["errors"]:raise ValueError(validation["errors"])
    # Raw AS text / raw XML intentionally remain outside production data.
    source_programs={str(sid):refs(sid)for sid in sorted(set(r["source_id"]for r in actions.values())|set(map(int,comp)))}
    rules={"schema_version":1,"character_id":"crt_4","source_crt":4,"source_fps":25,
      "status":"finite static source facts; native Flash timing and natural CRT4 input not yet dynamically compared",
      "default_profile":{"equipment_family":"crt_3","source_equipment_character_id":"crt_3",
        "source_fields":{"armor":"웨펀압","weapon":"웨펀무기","weapon_master":"weaponmaster","blaze":"블레이즈"},
        "initialized_values":{"armor":1,"weapon":0,"weapon_master":0,"blaze":0},
        "scope":"shared original Weaponmaster-family fields; no invented fifth equipment slot"},
      "actions":actions,"body":body,"components":comp,"hit_windows":windows,"named_common_slash":common_slash,"source_audio":audio,"validation":validation,
      "movement":{"source_parent":146,"base_root41":8,"persistent_root1":2.5,"ghostwalk_extra":2,
        "static_normal_total":10.5,"static_ghostwalk_total":12.5,"phase_validation":"not native/dynamic CRT4 proof",
        "parent_matrix":actions["move"]["parent_matrix"],"matrix_chain":actions["move"]["matrix_chain"]},
      "source_programs":source_programs,"source_selected":{"ordinary_x3_route":"retained source definition; no invented key route",
        "r_87_legacy_724":"excluded: parent87 DoAction returns146; callback reach unproven",
        "q_corrected":"6487 source7..8 applies3951; prior preliminary visual-only description superseded"},
      "unverified":["CRT4 original natural input and source callback phase have not been dynamically probed",
        "same-parent151 uses shared play_source_parent; do not assume a hardcoded151->152 mapping",
        "10ms/1000ms use host timer scheduler; no conversion to source25Hz callbacks",
        "source node replacement and global observers can affect total damage; no fixed total damage is asserted"]}
    imports={"schema_version":1,"character_id":"crt_4","animations":animations,
      "ACT06_ANIMATIONS":{k:[v["source_id"],v["frames"],v["loop"],v["offset"],v["parent_id"],v["parent_source_frame"]]for k,v in animations.items()},
      "parent_scales":{k:v["basis"][0]for k,v in animations.items()if v["basis"][1:3]==[0,0]and v["basis"][0]==v["basis"][3]and v["basis"][0]!=1},
      "selector_pages":{str(k):v for k,v in SELECTORS.items()},"appearance_by_source_frame":P["appearance_by_source_frame"],
      "independent_children_removed":{k:v["remove_child_ids"]for k,v in animations.items()if v["remove_child_ids"]},
      "source_child_omissions":{"6356":[6346]},
      "frame_child_omissions":[{"host":6360,"frame":20,"child":6346}],
      "sparse_visual_mapping":sparse,"body":body,"components_geometry":comp,"hit_windows":windows,
      "source_audio":audio,"named_common_slash":common_slash,"transparent_clocks_without_png":{"6359":{"frames":545,"parent":6360,"alpha_mult":0}},
      "render_stop_hold":{str(sid):min(x["frame"]for x in r["scripts"] if x["text"].strip()=="stop();")
        for sid,r in S.items()if any(x["text"].strip()=="stop();" for x in r.get("scripts",[]))},
      "visual_clock_reuse":{"3968/3969/3970":"Use crt4_clone_status, one original3968/1 depth1 filtered1149 nine-frame loop. Original3968/3969/3970 effective1149 matrix, COLORMATRIX and alpha223 are identical on1..135; source136 alpha0. Preserve full parent chain once with baked-filter inverse metadata; do not substitute unfiltered1326 flight atlas.",
        "943":"94221-frame independent loop at each recorded birth; parent35 can hold",
        "944":"932 independent placements;943 carries independent942 instances",
        "907":"861 depth1 clipDepth30 is a mask, not a visible black background. 906 independent40-clock is rendered through original907/1 mask wrapper; full child placement is baked once.",
        "6397/6404":"reuse6393 movement with independent6395/6402; preserve source placement chain"},
      "ui":{"hud_source_id":4391,"hud_source_frame":5,"warehouse_source_id":2728,"warehouse_source_frame":6,
            "cutin_key":"hud_crt4_cutin","cutin_source_frames":[130,161],"equipment_character_id":"crt_3"},
      "notes":["Do not import all raw scripts/XML/SWF or full frame library",
        "Source parent matrices and per-child alpha/filter must apply exactly once",
        "Basis-bearing standalone nested components may need original placement wrappers; preserve source filters",
        "Long lifetime parents are clocks+placement tracks, not hundreds of duplicate images"]}
    # Original1023/f7 is empty+stop;1273/f5 dust must hold empty7, including parent31.
    # This bounded dependency is absent from S; do not let nested rendering loop its seven frames.
    imports["render_stop_hold"]["1023"]=7
    for name,data in [("act06_crt4_rules.json",rules),("act06_crt4_import.json",imports)]:
        path=PROJECT/"data"/name
        path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print(json.dumps({"actions":len(actions),"windows":len(windows),"components":len(comp),
      "animations":len(animations),"selected_frames":sum(len(x["frames"])for x in animations.values()),
      "sound_sources":len(audio),"sound_events":sum(map(len,audio.values()))}))


if __name__=="__main__":main()
