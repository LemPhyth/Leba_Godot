"""ACT05 read-only resource investigation. Only investigation artifacts are written.

This is a selection/metadata draft, not an importer or proof of playable behavior.
Original SWF/XML/scripts and formal catalog/assets/content remain read-only.
"""
from __future__ import annotations

import argparse
import json
import re
import xml.etree.ElementTree as ET
from pathlib import Path

import import_runtime_assets as source

OUT = source.PROJECT / "artifacts/leba_act05_20261117/investigation"
ACTION_SPECS = {
    "crt3_idle": (5818, 101, [(1, 15)]),
    "crt3_move": (5817, 102, [(1, 12)]),
    "crt3_basic1": (5820, 106, [(1, 18)]),
    "crt3_basic2": (5821, 107, [(1, 19)]),
    "crt3_basic3": (5822, 108, [(1, 21)]),
    "crt3_skill_a": (5823, 109, [(1, 16)]),
    "crt3_skill_s1": (6025, 117, [(1, 17)]),
    "crt3_skill_s2": (6026, 118, [(1, 17)]),
    "crt3_skill_s3": (6032, 119, [(1, 19)]),
    "crt3_skill_d1": (6050, 120, [(1, 20)]),
    "crt3_skill_d2": (6052, 121, [(1, 20)]),
    "crt3_skill_d3": (6054, 122, [(1, 21)]),
    "crt3_skill_d4": (6055, 123, [(1, 20)]),
    "crt3_skill_d5": (6058, 124, [(1, 21)]),
    "crt3_skill_f": (6088, 125, [(1, 28)]),
    "crt3_skill_g": (6124, 126, [(1, 58)]),
    "crt3_skill_q": (6138, 127, [(1, 22)]),
    "crt3_skill_q_end": (6142, 128, [(1, 22)]),
    "crt3_skill_h": (6155, 129, [(1, 19)]),
    "crt3_backstep": (6158, 130, [(1, 12)]),
    "crt3_skill_w": (6177, 131, [(1,84)]),
    "crt3_skill_e": (6300, 132, [(1, 10)]),
    "crt3_hit": (6301, 133, [(1, 14)]),
    "crt3_air_hit": (6303, 134, [(1, 30)]),
    "crt3_knockdown": (6305, 136, [(1,1)]),
    "crt3_dead": (6307, 138, [(1, 25)]),
    "crt3_jump": (6311, 139, [(1,30),(57,67)]),
    "crt3_skill_v": (6312, 140, [(1,15),(17,78)]),
}
HUD_CONTROLS = {"a":4234,"s":4238,"d":4242,"f":4246,"g":4251,
    "q":4255,"h":4259,"w":4263,"e":4266,"v":4267,"air_z":4229}
HUD_LOCKED = [4272,4276,4283,4288]
WAREHOUSE_SELECTORS = [2682,2687,2690,2691,2692,2693,2694,2695,2696]
DEFAULT_SELECTORS = {i:1 for i in (23,24,46,47,55,56,67,152,156,163,1471,
    3631,3632,3674,3678,3679,3773,3774,3785,3786,3800,3823,5722,6084,
    6041,6044,6045,6053,6057)}
PARENT_WEAPON_PAGES = {6025:{7:4,8:1},6026:{4:3,6:4},6032:{5:3,7:4}}
EXTRA_IDS={6732,152,74,6156,6157,6308,6309,6044,6045,6053,6057,6067,6070,
    4614,4613,6276,6199,6299,6278,6259,5789,5815,5816,4545,6160,959,821,1030,1332,6177,166,6166}


def extra_audit() -> dict:
    symbols=source.read_source_symbols(EXTRA_IDS)
    result={}
    for ident,tag in symbols.items():
        if ident==6732:continue
        row={"source_id":ident,"type":tag.get("type"),"scripts":scripts(ident)}
        if tag.find("subTags")is not None:
            row["timeline"]=compact_timeline(tag);row["actual_frames"]=len(row["timeline"])
            row["filtered_placements"]=[];frame=1
            for t in tag.find("subTags"):
                if t.get("type")=="ShowFrameTag":frame+=1
                if t.find("surfaceFilterList")is not None:
                    row["filtered_placements"].append({"source_frame":frame,"depth":int(t.get("depth")),
                        "source_id":int(t.get("characterId",-1)),"matrix":source.source_matrix(dict(t.find("matrix").attrib))if t.find("matrix")is not None else None,
                        "filters_xml":ET.tostring(t.find("surfaceFilterList"),encoding="unicode")})
        if tag.find("shapeBounds")is not None:row["bounds_twips"]=dict(tag.find("shapeBounds").attrib)
        result[str(ident)]=row
    original={};frame=1
    for tag in symbols[6732].find("subTags"):
        if tag.get("type")=="ShowFrameTag":frame+=1
        if frame in(14,74,133)and tag.get("characterId")=="4689":
            original[str(frame)]={"matrix":source.source_matrix(dict(tag.find("matrix").attrib)),
                "filters_xml":ET.tostring(tag.find("surfaceFilterList"),encoding="unicode")if tag.find("surfaceFilterList")is not None else None,
                "color_transform":dict(tag.find("colorTransform").attrib)if tag.find("colorTransform")is not None else None}
    result["player_hit_fx_equivalence"]={"source_placements":original,
        "basis_and_filters_equal_14_133":original['14']['matrix'][:4]==original['133']['matrix'][:4]and original['14']['filters_xml']==original['133']['filters_xml']and original['14']['color_transform']==original['133']['color_transform']}
    (OUT/"act05_extra_symbols.json").write_text(json.dumps(result,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    return result


def make_plan(data:dict) -> dict:
    """Curated source ranges only. Pending rows never enter ANIMATIONS."""
    specs={};scales={};bpages={};commands={};pending=[]
    for key,(ident,parent,ranges)in ACTION_SPECS.items():
        row=data["actions"][key];matrix=row["parent_placement"]["matrix"]
        if not ranges:pending.append(key);continue
        frames=[f for lo,hi in ranges for f in range(lo,hi+1)]
        if any(f>row["declared_frame_count"]for f in frames):raise ValueError(f"Selection exceeds original {key}")
        specs[key]=[ident,frames,key in("crt3_idle","crt3_move"),matrix[4:],6732,parent]
        scales[key]=[matrix[0],matrix[3]]
        changes={}
        for script in row["scripts"]:
            f=script["source_frame"]
            if f not in frames or not script["path"].endswith("DoAction.as"):continue
            found=re.findall(r"^\s*(?:_root\.일\.동작\.)?w\.b\.gotoAndStop\((\d+)\);",script["text"],re.M)
            if found:changes[f]=int(found[-1])
        changes.update(PARENT_WEAPON_PAGES.get(ident,{}))
        # Commands include every explicit reset1. Pages below are a rendering
        # selection for the reviewed chronological branch, not an AVM scheduler.
        page=1;pages={}
        for f in frames:
            page=changes.get(f,page);pages[str(f)]=page
        bpages[key]=pages;commands[key]={str(f):p for f,p in sorted(changes.items())}
    specs["hud_crt3_e_cutin"]=[6835,list(range(98,130)),False,[-771.15,16.6],6917,1]
    scales["hud_crt3_e_cutin"]=[1,1]
    extra_path=OUT/"act05_extra_symbols.json"
    extra=json.loads(extra_path.read_text(encoding="utf-8"))if extra_path.exists()else{}
    component_ranges={"crt3_jump_attack":(6308,[(1,11)]),"crt3_backstep_attack":(6156,[(1,15)]),
        "crt3_f_hit":(6067,[(1,4)]),"crt3_q_clone_right":(959,[(1,8)]),"crt3_q_clone_left":(821,[(1,8)]),
        "crt3_q_end_clone_right":(1030,[(1,8)]),"crt3_q_end_clone_left":(1332,[(1,8)]),
        "crt3_h_timer":(4614,[(1,9),(401,407)]),"crt3_e_actor":(6276,[(1,148)]),
        "crt3_e_circle":(6199,[(1,11)]),"crt3_e_start":(6299,[(1,45)]),
        "crt3_e_streak":(6278,[(1,44)]),"crt3_e_hit":(6259,[(1,4)]),
        "crt3_w_illusion":(166,[(1,59)]),"crt3_w_subattack":(6166,[(1,14)])}
    for key,(ident,ranges)in component_ranges.items():
        frames=[f for lo,hi in ranges for f in range(lo,hi+1)]
        specs[key]=[ident,frames,False,[0.,0.],None,None];scales[key]=[1,1]
        if str(ident)in extra:
            changes={}
            for script in extra[str(ident)]["scripts"]:
                if not script["path"].endswith("DoAction.as"):continue
                found=re.findall(r"^\s*(?:[\w.]+\.)?w\.b\.gotoAndStop\((\d+)\);",script["text"],re.M)
                if found:changes[script["source_frame"]]=int(found[-1])
            page=1;pages={}
            for f in frames:page=changes.get(f,page);pages[str(f)]=page
            bpages[key]=pages;commands[key]={str(f):p for f,p in sorted(changes.items())}
    def track(timeline,child):
        return {f:[r for r in rows if r["source_id"]==child]for f,rows in timeline.items()if any(r["source_id"]==child for r in rows)}
    tracks={}
    for parent,children in {6311:[6308,6309],6158:[6156,6157],6088:[6067],6177:[6166],6300:[6276,6199,6299],6276:[6259,6199],6299:[6278]}.items():
        timeline=extra[str(parent)]["timeline"]if str(parent)in extra else next(a["timeline"]for a in data["actions"].values()if a["source_id"]==parent)
        tracks[str(parent)]={str(c):track(timeline,c)for c in children}
    plan={"ACT05_ANIMATIONS":specs,"parent_scales":scales,
        "selector_pages":{str(i):v for i,v in DEFAULT_SELECTORS.items()},
        "hide_instances":{"46":["wing","전펙"]},
        "weapon_shape_selector":{"parent_id":152,"parent_page":1,"child_id":74,"child_name":"b","child_offset":[4.9,4.7],
            "source_commands_by_animation":commands,"render_page_by_source_frame":bpages,
            "contract":"Freeze152 at default page1. Render74 at the per-source-frame requested page, not a natural6-frame loop and not permanently page1. All parts using152 in one rendered main frame share this default visual weapon. These are source-script selection tables, not natural-input runtime validation."},
        "independent_children_removed":{"6311":[6308,6309],"6158":[6156,6157],"6088":[6067],"6177":[6166],"6300":[6276,6199,6299],"6276":[6259,6199],"6299":[6278]},
        "independent_placement_tracks":tracks,
        "transparent_clocks_without_png":{"6309":{"count":11,"stop":1,"end11_goto":1,"visible_source_frames":[]},
            "6157":{"count":4,"stop":1,"natural_wrap":True,"visible_source_frames":[],"primitive_id":1407,"primitive_rect":[-49.5,-36.5,99.05,73.0],"primitive_alpha":0,"active_source_frame":4,"primitive_matrix":[1.4411926,0,0,2.6273956,35,-21.7],"evidence":"res/shapes/1407.svg fill-opacity0; original6157f4 PNG has empty alpha; geometric rect comes from source shape, never from PNG."}},
        "render_stop_hold":{"6083":9,"6217":1,"6223":6,"6247":7,"6250":11,"6262":11,"6265":11,"6268":11,"6254":4,"6275":10,"6293":36},
        "render_stop_hold_contract":"For bounded6276 rendering, truncate each listed child's original timeline after its stop frame and pad unchanged end display list through at least148 frames. Keep original metadata/frame counts. Do not naturally loop a stopped effect; do not expose padding as source frames.",
        "sparse_visual_mapping":{"crt3_h_timer":{"source_clock_count":407,"map_9_through_400_to_visual_frame":9,"source_401_through_407":"keep original source frames","reason":"4613 child is1-frame; effective display/transform unchanged through9..400; observer changes401 are clock rules, not deduced from image."}},
        "e_streak_wrapper":{"source_id":6278,"parent_id":6299,"parent_source_frame":1,"depth":1,
            "same_filter_depths":[1,3,5,7,9,11,13,15],"matrix":[1,0,0,1,128.25,-50.05],"baked_placement_matrix":[1,0,0,1,0,0],"baked_alpha_mult":256,
            "filter":"Original COLORMATRIXFILTER RGB+17, alpha unchanged. Clone original placement with zero translation; all8 filters equal. Keep external placement128.25,-50.05 and staggered entry source frames.",
            "entry_by_depth":{"1":1,"3":3,"5":6,"7":9,"9":12,"11":15,"13":18,"15":21},"stop_source_frame":44},
        "reuse_animations":{"dust_right":"crt2_q_dust_right","dust_left":"crt2_q_dust_left","air_z_right":"crt2_air_z_right","air_z_left":"crt2_air_z_left","knife_left":"crt2_hit_slash_left","knife_horizontal":"crt2_hit_slash_horizontal","knife_right":"crt2_hit_slash_right"},
        "pending_main_range":pending,"independent_pending":"No unreviewed alternative skill branch is included. Chronological baking of finite source children remains a derived-render operation, not host scheduling validation.",
        "q_random_audio":{"host_id":6138,"source_frame":4,"random_count":2,"choice_to_sound_id":{"0":2,"1":1},"choice_to_linkage":{"0":"맹룡1","1":"맹룡2"},"in_point_samples_44100":0,"aliases":{"0":"crt3_q_random_0","1":"crt3_q_random_1"},"source":"res/scripts/DefineSprite_6138/frame_4/DoAction.as; res/symbolClass/symbols.csv"},
        "script_audio_extra":{"f_hit":{"source_id":6067,"source_frame":2,"sound_id":10,"linkage":"차지","alias":"crt3_f_contact","in_point_samples_44100":0},
            "knife_hit":{"source_ids":[1481,1489,1496],"source_frame":1,"sound_id":4,"linkage":"광검","alias":"crt3_hit_slash_sound4","in_point_samples_44100":0,"default_rule":"crt3 armor1 weapon0 chooses광검4. Armor4 additionally chooses구구3; weapon2 chooses대검6, both outside default. Reuse visual knife atlases, not CRT2 sound6."},
            "e_hit":{"source_id":6259,"source_frame":1,"random_count":3,"choice_to_sound_id":{"0":12,"1":13,"2":9},"choice_to_linkage":{"0":"1","1":"2","2":"3"},"in_point_samples_44100":0,"also_start_sound_id":6256,"note":"Random script sound and source StartSound6256 both occur; do not replace one with the other."}},
        "player_hit_fx":{"animation":"player_hit_fx","source_id":4689,"parent_frame":133,"offset_px":[14.7,35.15],"matrix":[.3622589,0,0,.3516693,14.7,35.15],"source_filter_equivalence":extra.get("player_hit_fx_equivalence",{}),"note":"Raw6732 parent133 basis/filters/CXFORM compared exactly equal to14; offset equalsCRT2. Reuse filtered4689 atlas."},
        "e_cutin":data["e_cutin"],"scope":"Draft for Root importer only. No formal resource or original file has been modified by this analyzer."}
    for name,parent,child in (("e_streak_wrapper",6299,6278),("w_subattack_wrapper",6177,6166)):
        rows=[r for r in extra.get(str(parent),{}).get('filtered_placements',[])if r['source_id']==child]
        if rows:
            assert len({r['filters_xml']for r in rows})==1, f"Different source filters need separate wrappers: {child}"
            plan.setdefault(name,{}).update({"source_id":child,"parent_id":parent,
                "source_parent_frame":rows[0]['source_frame'],"source_depth":rows[0]['depth'],"filters_xml":rows[0]['filters_xml'],
                "recommended_wrapper_matrix":[1,0,0,1,0,0],"recommended_baked_placement_matrix":[1,0,0,1,0,0],
                "contract":"Clone exact original filter and CXFORM, set wrapper matrix fully identity to bake local filters only; keep each original per-instance matrix external. If renderer retains source basis instead, record that actual baked basis and compensate its inverse. Never publish identity metadata for a nonidentity baked wrapper."})
    hit_rows=[r for r in extra.get('6276',{}).get('filtered_placements',[])if r['source_id']==6259]
    if hit_rows:
        plan['e_hit_parent_wrappers']={"source_id":6259,"same_filter_count":len({r['filters_xml']for r in hit_rows}),
            "unique_basis_count":len({tuple(r['matrix'][:4])for r in hit_rows}),"filters_xml":hit_rows[0]['filters_xml'],
            "variants":[{"animation_key":f"crt3_e_hit_depth_{r['depth']}","parent_source_frame":r['source_frame'],"parent_depth":r['depth'],
                "spec":[6259,[1,2,3,4],False,[0,0],None,None],"baked_placement_matrix":r['matrix'][:4]+[0,0],"baked_alpha_mult":256,
                "external_original_matrix":r['matrix']}for r in hit_rows],
            "contract":"Unlike the COLOR matrices, two original GLOW filters are spatial. For strict parent-filter correspondence clone each of24 distinct source placement bases with zero translation, then runtime authorMatrix*baked.inverse. A shared identity-filtered image would rotate/scale anisotropic glow and is an explicit visual approximation. Variant metadata is an importer proposal; the base44 whitelist has not silently expanded.",
            "audio_contract":"All variants use the same6259 independent clock/audio prefix; do not request24 extra sounds when one source instance is born."}
    plan['parent_filter_audit']={"H4614":{"parent_id":6732,"source_frame":1,"depth":1062,"type":"PlaceObject2Tag","filter":None,"color_transform":None,"wrapper_required":False},
        "E6300_source10_children":{"source_ids":[6276,6199,6299],"filters":None,"color_transforms":None,"wrapper_required":False},
        "source":"Direct original XML tag inspection2026-11-17; nested removed children still require their own filters."}
    special_path=OUT/'crt3_special.json'
    if special_path.exists():
        special=json.loads(special_path.read_text(encoding='utf-8'))
        plan['W_independent']=special.get('W',{})
        plan['audio_source_contract']='Top-level StartSound events selected by ACT05_ANIMATIONS source frames, plus independent clocks and script_audio_extra/Q random. Source StartSound envelope/inPoint/outPoint must be preserved; source IDs alone do not establish trigger counts.'
    if "4545"in extra:
        b=extra["4545"]["bounds_twips"];base=[int(b["Xmin"])/20,int(b["Ymin"])/20,(int(b["Xmax"])-int(b["Xmin"]))/20,(int(b["Ymax"])-int(b["Ymin"]))/20]
        def tx(rect,m):
            x,y,w,h=rect;points=[(m[0]*a+m[2]*b+m[4],m[1]*a+m[3]*b+m[5])for a,b in((x,y),(x+w,y),(x,y+h),(x+w,y+h))]
            xs=[p[0]for p in points];ys=[p[1]for p in points]
            return[round(min(xs),9),round(min(ys),9),round(max(xs)-min(xs),9),round(max(ys)-min(ys),9)]
        clips={}
        for ident,body in data['body_clips'].items():
            stops=sorted(s['source_frame']for s in body['scripts']if s['path'].endswith('DoAction.as')and re.search(r'(?<!\.)\bstop\s*\(',s['text']))
            clips[ident]={"frame_count":len(body['timeline']),"source_shape_id":4545,"empty_is_absent":True,"stop_frames":stops,
                "rects_by_source_frame":{f:[tx(base,r['matrix'])for r in rows if r['source_id']==4545]for f,rows in body['timeline'].items()}}
            if len(stops)==1:clips[ident]['stop_source_frame']=stops[0]
        plan['act05_crt3_body']={"parents":{f:{name:next((r for r in rows if r['name']==name),None)for name in('몸빵','중력몸빵')}for f,rows in data['parent_body'].items()},"clips":clips,
            "rect_space":"Clips already include primitive4545 inner placement. Apply selected parent placement once. Missing parent/empty frame means absent; never fall back to CRT0 body.","source":"res/structure/game.xml; source shape4545; exact original body stop scripts."}
    errors=[]
    for key,(ident,frames,loop,offset,parent,pframe)in specs.items():
        if frames!=sorted(set(frames))or any(not isinstance(f,int)or f<1 for f in frames):errors.append(f"invalid integer source frames:{key}")
        if any(v not in range(1,7)for v in bpages.get(key,{}).values()):errors.append(f"invalid weapon page:{key}")
        actual=extra.get(str(ident),{}).get('actual_frames')
        if actual is not None and max(frames)>actual:errors.append(f"out of original source range:{key}")
        if parent==6732 and any(a['source_id']==ident for a in data['actions'].values()):
            a=next(a for a in data['actions'].values()if a['source_id']==ident)
            if offset!=a['parent_placement']['matrix'][4:]:errors.append(f"parent pivot offset mismatch:{key}")
    catalog=json.loads(source.CATALOG.read_text(encoding='utf-8'))
    for key in plan['reuse_animations'].values():
        if key not in catalog['animations']:errors.append(f"missing reusable animation:{key}")
    if errors:raise ValueError(errors)
    plan['static_validation']={"selected_animation_count":len(specs),"selected_frame_count":sum(len(v[1])for v in specs.values()),"errors":errors,
        "checks":["integer ordered source frames","bounded selected extra symbols","weapon pages1..6","main parent offsets match original XML","existing shared animation references present"],
        "not_tested":["new FFDec derived PNGs","Godot runtime","visible window","audio listening","natural Flash input"]}
    output=OUT/"act05_import_plan.json";temporary=output.with_suffix('.json.tmp')
    temporary.write_text(json.dumps(plan,ensure_ascii=False,indent=2)+"\n",encoding="utf-8");temporary.replace(output)
    return plan


def scripts(ident: int) -> list[dict]:
    result=[]
    folders=list((source.SOURCES/"scripts").glob(f"DefineSprite_{ident}"))
    folders += list((source.SOURCES/"scripts").glob(f"DefineSprite_{ident}_*"))
    for folder in folders:
        for path in sorted(folder.rglob("*.as")):
            match=re.search(r"frame_(\d+)",path.as_posix())
            result.append({"path":path.relative_to(source.WORKSPACE).as_posix(),
                "source_frame":int(match[1])if match else None,
                "sha256":source.sha256(path),"text":path.read_text(encoding="utf-8")})
    return result


def index_symbols() -> dict[int,dict]:
    """One compact index scan; no full source tag/bitmap tree is imported."""
    result={};stack=[]
    for event,tag in ET.iterparse(source.SOURCES/"structure/game.xml",events=("start","end")):
        if event=="start":stack.append(tag);continue
        if len(stack)==3 and tag.tag=="item":
            typ=tag.get("type","")
            ident=next((tag.get(k)for k in("spriteId","shapeId","buttonId","characterID","textId","fontID","soundId")if tag.get(k)is not None),None)
            if ident is not None and typ.startswith("Define") and not any(x in typ for x in("Info","Name","Align","Cxform","ButtonSound")):
                bounds=tag.find("shapeBounds")
                result[int(ident)]={"type":typ,"declared_frame_count":int(tag.get("frameCount",0)),
                    "children":sorted({int(t.get("characterId"))for t in tag.iter("item")if t.get("characterId")is not None}),
                    "shape_bounds_twips":dict(bounds.attrib)if bounds is not None else None}
            tag.clear()
        stack.pop()
    return result


def placement(row:dict) -> dict:
    return {"source_id":int(row.get("characterId",-1)),"depth":int(row["depth"]),
        "name":row.get("name"),"matrix":source.source_matrix(row.get("matrix",{})),
        "alpha_mult":int(row.get("colorTransform",{}).get("alphaMultTerm",256))}


def compact_timeline(tag, frames=None) -> dict:
    values=source.source_frames(tag)
    return {str(f):[placement(r)for r in rows.values()]for f,rows in values.items()if frames is None or f in frames}


def audit() -> dict:
    index=index_symbols()
    body_ids={4546,4547,4673,4745,5470}
    ids={6732,4391,2728,6917,6835,4689,2675,4289,4290,2671,2672,2673,*body_ids,
        *HUD_CONTROLS.values(),*HUD_LOCKED,4268,*WAREHOUSE_SELECTORS,*[v[0]for v in ACTION_SPECS.values()]}
    symbols=source.read_source_symbols(ids)
    actor=source.source_frames(symbols[6732]);actions={}
    for key,(ident,parent,ranges)in ACTION_SPECS.items():
        row=next(r for r in actor[parent].values()if int(r.get("characterId",-1))==ident)
        frames={f for lo,hi in ranges for f in range(lo,hi+1)}
        facts=scripts(ident)
        actions[key]={"source_id":ident,"parent_id":6732,"parent_source_frame":parent,
            "parent_placement":placement(row),"selected_ranges":ranges,"selection_status":"reviewed main route; child clocks separately required"if ranges else"pending teammate route selection; do not import entire source",
            "declared_frame_count":index[ident]["declared_frame_count"],"timeline":compact_timeline(symbols[ident],frames or None),"scripts":facts}
    parent_body={str(f):[placement(r)for r in actor[f].values()if r.get("name")in("몸빵","중력몸빵")]for f in range(101,141)}
    hit_fx={str(f):[placement(r)for r in actor[f].values()if r.get("name")=="타격"]for f in(133,134)}
    # Keep raw source controls for every body; no implied shared clock or PNG bounds.
    bodies={str(i):{"timeline":compact_timeline(symbols[i]),"scripts":scripts(i)}for i in body_ids}
    bar=source.source_frames(symbols[4391])[4]
    hud={"source_id":4391,"source_frame":4,"controls":HUD_CONTROLS,"locked_ids":HUD_LOCKED,
        "not_a_default_input":[4238,4268],"dynamic_fields":{"gold":4289,"clear_cubes":4290},
        "placements":[placement(r)for r in bar.values()],"slot_scripts":{str(i):scripts(i)for i in {*HUD_CONTROLS.values(),*HUD_LOCKED,4268}}}
    warehouse={"source_id":2728,"source_frame":5,"placements":compact_timeline(symbols[2728],{5})["5"],
        "dynamic_fields":{"gold":2671,"clear_cubes":2672,"pama":2673},"inventory_selectors":{str(i):{"default_page":1,"scripts":scripts(i)}for i in WAREHOUSE_SELECTORS},
        "nav_ids":[2635,2636,2637,2638,2639],"visual_title":"仓库 (original full frame visual inspection; shared header)",
        "decorative_panel_source":2675,"decorative_panel_definition":ET.tostring(symbols[2675],encoding="unicode")}
    cutin_row=next(r for r in source.source_frames(symbols[6917])[1].values()if r.get("characterId")=="6835")
    cutin={"key":"hud_crt3_e_cutin","source_id":6835,"selected_ranges":[[98,129]],"immediate_parent":6917,
        "immediate_placement":placement(cutin_row),"initial_parent_offset_baked":True,
        "external_transform":"Apply only root6917 matrix. Immediate6835 translation is in atlas pivot; do not add it again.",
        "root_placements_by_source_frame":source.selected_root_placements({6917},{2,4,6,9,41}),
        "scripts":[r for r in scripts(6835)if 98<=r["source_frame"]<=129]}
    # Candidate closure is not an import list: it deliberately includes alternate selector pages.
    closure=set(v[0]for v in ACTION_SPECS.values());pending=list(closure)
    while pending:
        ident=pending.pop()
        for child in index.get(ident,{}).get("children",[]):
            if child not in closure and index.get(child,{}).get("type")=="DefineSpriteTag":closure.add(child);pending.append(child)
    candidates={}
    for ident in sorted(closure):
        s=scripts(ident)
        first=[r for r in s if r["source_frame"]==1 and Path(r["path"]).name=="DoAction.as"]
        if first and any("stop()"in r["text"]or"gotoAndStop"in r["text"]for r in first):
            candidates[str(ident)]={"definition":index[ident],"source_frame1":first,"status":"candidate only; resolve default branch before rendering"}
    result={"source":"res/structure/game.xml and original exported AS2; static investigation only",
        "source_xml_sha256":source.sha256(source.SOURCES/"structure/game.xml"),"actions":actions,"parent_body":parent_body,
        "body_clips":bodies,"player_hit_fx":hit_fx,"hud":hud,"warehouse":warehouse,"e_cutin":cutin,
        "selector_candidates":candidates,"dependency_candidate_count":len(closure),
        "pivot_contract":"Existing build_animation pivot includes selected main parent's translation. Parent basis remains parent_scale. Independent parts at offset0 require their external placement once.",
        "excluded":"Locked equipment/master/awakening branches, unrelated parent110..116,135/137 unless source default transition proves needed. Candidate closure is not an import whitelist."}
    OUT.mkdir(parents=True,exist_ok=True)
    (OUT/"act05_assets.json").write_text(json.dumps(result,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    make_plan(result)
    return result


if __name__=="__main__":
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument("--plan-only",action="store_true");parser.add_argument("--extra",action="store_true");args=parser.parse_args()
    if args.extra:
        result=extra_audit();print(json.dumps({"extra_symbols":len(result),"hit_fx_equivalent":result['player_hit_fx_equivalence']['basis_and_filters_equal_14_133']}));raise SystemExit(0)
    if args.plan_only:
        result=make_plan(json.loads((OUT/"act05_assets.json").read_text(encoding="utf-8")))
        print(json.dumps({"plan":str(OUT/"act05_import_plan.json"),"selected":len(result["ACT05_ANIMATIONS"]),"pending":result["pending_main_range"]}));raise SystemExit(0)
    result=audit()
    print(json.dumps({"artifact":str(OUT/"act05_assets.json"),"actions":len(result["actions"]),"selector_candidates":len(result["selector_candidates"]),"status":"readonly draft; no formal resource writes"}))
