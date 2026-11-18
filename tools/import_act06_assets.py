"""ACT06 bounded derived subsets; original SWF/extraction and author files stay read-only."""
from __future__ import annotations
import argparse
import json
import tempfile
import hashlib
from PIL import Image
from pathlib import Path
import import_runtime_assets as shared

TASK = shared.PROJECT / "artifacts/leba_act06_20261117"

def crt4_beast_mask_setup() -> str:
    # Original907 contains mask861(depth1,clipDepth30) and906(depth2). Render
    # independent child ages inside that exact mask;861 is never a black panel.
    return """
{SWF original=new SWF(new FileInputStream(args[0]),false);
DefineSpriteTag source=(DefineSpriteTag)swf.getCharacter(906);
DefineSpriteTag body=(DefineSpriteTag)source.cloneTag();int bodyId=swf.getNextCharacterId();
body.setCharacterId(bodyId);body.setSwf(swf);swf.addTag(body);swf.updateCharacters();
for(Tag t:source.getTags().toArrayList())source.removeTag(t);
for(Tag t:((DefineSpriteTag)original.getCharacter(907)).getTags()) {
 if(t instanceof ShowFrameTag)continue;
 Tag clone=t.cloneTag();clone.setSwf(swf);
 if(clone instanceof PlaceObjectTypeTag && ((PlaceObjectTypeTag)clone).getCharacterId()==906)((PlaceObjectTypeTag)clone).setCharacterId(bodyId);
 source.addTag(clone);
}
for(int f=0;f<40;f++)source.addTag(new ShowFrameTag(swf));
source.setFrameCount(40);source.resetTimeline();source.setModified(true);swf.clearAllCache();}
"""

def extend_stopped_clip(ident: int, count: int) -> str:
    # Rendering-only copy: retain the stopped parent display list while children
    # finish. Export ages are explicit; this does not change original source IDs.
    return """{DefineSpriteTag hold=(DefineSpriteTag)swf.getCharacter(%d);int count=0;
for(Tag t:hold.getTags())if(t instanceof ShowFrameTag)count++;
while(count<%d){hold.addTag(new ShowFrameTag(swf));count++;}
hold.setFrameCount(count);hold.resetTimeline();hold.setModified(true);}
""" % (ident, count)

def import_crt3_waves() -> None:
    shared.verify_catalog()
    if shared.sha256(shared.SWF) != shared.EXPECTED_SWF_SHA256:
        raise ValueError("Original SWF differs from reviewed source")
    catalog = json.loads(shared.CATALOG.read_text(encoding="utf-8"))
    previous = {r["path"]: r["sha256"] for r in catalog["outputs"]}
    specs = {"crt3_sword_wave_right": (1267, list(range(1,23)), False, [0,0], None, None),
             "crt3_sword_wave_left": (1311, list(range(1,23)), False, [0,0], None, None)}
    shared.ANIMATIONS.update(specs)
    shared.FRAME_TRIM_KEYS.update(specs)
    setup = "\n".join(extend_stopped_clip(i,22) for i in (1254,1267,1311))
    folder = TASK / "wave_render"
    folders, bounds = shared.render_default_player_frames(folder, list(specs), source_setup=setup)
    provenance = [shared.source_record(shared.SWF),shared.source_record(shared.SOURCES/"structure/game.xml")]
    for key, spec in specs.items():
        ident = spec[0]
        catalog["animations"][key] = shared.build_animation(key,spec,bounds,previous,provenance,folders[ident],{f:18 for f in range(19,23)})
        catalog["animations"][key].update({"render_profile":"act06_wave_independent_tail",
            "parent_stop_source_frame":18,"render_age_to_parent_source_frame":{str(f):min(f,18) for f in range(1,23)},
            "derivation":"Original parent stops18; newly placed dust1254 independently reaches empty stop6. Rendering-only parent hold18 and dust hold6, through age22; age22 empty remains inert until source depth replacement/scene exit."})
        for directory in shared.SOURCES.joinpath("scripts").glob(f"DefineSprite_{ident}_*"):
            provenance.extend(shared.source_record(p) for p in directory.rglob("*.as"))
    for directory in shared.SOURCES.joinpath("scripts").glob("DefineSprite_1254*"):
        provenance.extend(shared.source_record(p) for p in directory.rglob("*.as"))
    catalog["render_profiles"]["act06_wave_independent_tail"]={"source_parents":[1267,1311],"source_stop":18,"independent_child":1254,"child_empty_stop":6,"tail_render_age":22,"root_offset_baked":False,"root_scale":[1,1]}
    shared.act05_publish(catalog,provenance)
    changed = [p for p,h in previous.items() if shared.sha256(shared.PROJECT/p)!=h]
    if changed:raise ValueError(f"Unrelated output changed: {changed}")
    print(json.dumps({"imported":list(specs),"preexisting_outputs_unchanged":len(previous)}))

def import_crt4_ui() -> None:
    shared.verify_catalog()
    catalog=json.loads(shared.CATALOG.read_text(encoding="utf-8"))
    previous={r["path"]:r["sha256"] for r in catalog["outputs"]}
    hud=shared.hud_source_geometry(4)
    key="hud_panel_crt4_ready"
    spec={"source_id":4391,"mode":"panel_crt4_ready","source_frame":5,"stage_position":[12.95,57.1]}
    with tempfile.TemporaryDirectory(prefix="leba_act06_hud_") as temp:
        images,bounds=shared.render_ui_frames(Path(temp),{key:spec})
        catalog["textures"][key]=shared.store_ui_texture(key,images[key],bounds[key],spec,previous)
    catalog["source_geometry"]["battle_hud_crt4"]=hud
    provenance=[shared.source_record(shared.SWF),shared.source_record(shared.SOURCES/"structure/game.xml")]
    for field in hud["dynamic_fields"].values():provenance.append(shared.source_record(shared.WORKSPACE/field["source_text_definition"]))
    for skill in hud["skills"].values():
        if skill["cooldown"].get("source"):provenance.append(shared.source_record(shared.WORKSPACE/skill["cooldown"]["source"]))
        provenance.extend(shared.source_record(p) for p in (shared.SOURCES/f"scripts/DefineSprite_{skill['source_id']}").rglob("*.as"))
    symbols=shared.read_source_symbols({2728,2349,2401,2444,2502,2671,2672,2673,2639,2050,2635,*range(2698,2707)})
    state=shared.source_frames(symbols[2728])[6]
    def row(child):
        placement=next(r for r in state.values() if r.get("characterId")==str(child))
        return {"source_id":child,"depth":int(placement["depth"]),"matrix":shared.source_matrix(placement.get("matrix",{}))}
    def field(child):
        tag=symbols[child];bounds=tag.find("bounds")
        return {**row(child),"source_variable":tag.get("variableName"),"font_id":int(tag.get("fontId")),"font_size_px":int(tag.get("fontHeight"))/20,"align":int(tag.get("align")),"bounds_local":[int(bounds.get(k))/20 for k in ("Xmin","Ymin","Xmax","Ymax")],"source_initial_text":tag.get("initialText"),"initial_text_rule":"Read current shared profile; source placeholder does not assert ownership."}
    ui=catalog["source_geometry"]["source_ui"]
    ui["buttons"].update(shared.source_button_geometry({"warehouse_crt4_rings":2639},symbols))
    controls={name:{**row(ident),"button_key":name}for name,ident in (("warehouse_close",2050),("warehouse_weapons",2635),("warehouse_crt4_rings",2639))}
    ui["warehouse"]["pages"]["6"]={"source_frame":6,"texture":"source_warehouse_crt4_shared_panel","buttons":controls,"fields":{name:field(child)for name,child in zip(("gold","clear_cubes","pama_stones"),(2671,2672,2673))},"source_character_id":4,"shared_equipment_character_id":3,"render_rule":"Original2728 page6,2401 source2(shared necklace),2699..2706 source1 empty. No fifth weapon/ring family. Unsupported transactions remain disabled; shared four-family ring page8 works."}
    ui["warehouse"]["scope"]+=" ACT06 page6 uses CRT3/4 shared equipment family; no independent fifth ring slot."
    shared.append_warehouse_control_metadata(catalog,symbols,pages=(6,))
    specs={"source_warehouse_crt4_shared_panel":{"source_id":2728,"mode":"warehouse_static_6"}}
    for state_name in ("up","over","down"):specs["source_warehouse_crt4_rings_"+state_name]={"source_id":2639,"mode":"button_"+state_name}
    for ident in (2728,2401,2699,2700,2701,2702,2703,2704,2705,2706,2542,2308):
        for pattern in (f"DefineSprite_{ident}",f"DefineButton2_{ident}"):
            provenance.extend(shared.source_record(p)for p in (shared.SOURCES/"scripts"/pattern).rglob("*.as"))
    # Publish the HUD output too; the UI publisher registers its own selected textures.
    outputs={r["path"]:r for r in catalog["outputs"]};out=catalog["textures"][key]["output"];outputs[out["path"]]=out;catalog["outputs"]=list(outputs.values())
    shared.publish_source_ui_parts(catalog,previous,specs,provenance)
    if any(shared.sha256(shared.PROJECT/p)!=h for p,h in previous.items()):raise ValueError("CRT4UI changed an unrelated output")

def import_crt4_animations(keys: list[str]) -> None:
    plan=json.loads((shared.PROJECT/"data/act06_crt4_import.json").read_text(encoding="utf-8"))
    rows=plan["animations"]
    if "all" in keys:keys=list(rows)
    if set(keys)-set(rows):raise ValueError("Unreviewed CRT4 animation key")
    shared.verify_catalog()
    if shared.sha256(shared.SWF)!=shared.EXPECTED_SWF_SHA256:raise ValueError("Original SWF changed")
    catalog=json.loads(shared.CATALOG.read_text(encoding="utf-8"));before={r["path"]:r["sha256"]for r in catalog["outputs"]}
    previous=before.copy();provenance=[shared.source_record(shared.SWF),shared.source_record(shared.SOURCES/"structure/game.xml")]
    specs={k:tuple(plan["ACT06_ANIMATIONS"][k])for k in keys}
    shared.ANIMATIONS.update(specs);shared.FRAME_TRIM_KEYS.update(keys);shared.PARENT_SCALES.update({k:[v,v] if isinstance(v,(int,float)) else v for k,v in plan["parent_scales"].items()})
    setup="\n".join(f"selectPage(swf,{int(i)},{int(page)});"for i,page in plan["selector_pages"].items())
    setup+="\n"+"\n".join("omitChildren(swf,%d,new int[]{%s});" % (int(rows[k]["source_id"]), ",".join(map(str,ids))) for k,ids in plan["independent_children_removed"].items())
    setup+="\n"+"\n".join("omitChildren(swf,%d,new int[]{%s});"%(int(sid),",".join(map(str,ids)))for sid,ids in plan.get("source_child_omissions",{}).items())
    for omitted in plan.get("frame_child_omissions",[]):
        setup+="\n{DefineSpriteTag host=(DefineSpriteTag)swf.getCharacter(%d);int page=1;for(Tag t:host.getTags().toArrayList()){if(t instanceof ShowFrameTag)page++;else if(page==%d && t instanceof PlaceObjectTypeTag && ((PlaceObjectTypeTag)t).getCharacterId()==%d)host.removeTag(t);}host.resetTimeline();host.setModified(true);}\n"%(int(omitted["host"]),int(omitted["frame"]),int(omitted["child"]))
    setup+='\n{DefineSpriteTag torso=(DefineSpriteTag)swf.getCharacter(46);for(Tag t:torso.getTags().toArrayList())if(t instanceof PlaceObjectTypeTag && Arrays.asList("wing","전펙").contains(((PlaceObjectTypeTag)t).getInstanceName()))torso.removeTag(t);torso.resetTimeline();torso.setModified(true);}\n'
    targets={int(v["source_id"])for v in rows.values()}
    for sid,stop in plan.get("render_stop_hold",{}).items():
        if int(sid) in targets or sid in plan["selector_pages"]:continue
        setup+="\n{DefineSpriteTag hold=(DefineSpriteTag)swf.getCharacter(%d);int count=0;boolean after=false;for(Tag t:hold.getTags().toArrayList()){if(after)hold.removeTag(t);else if(t instanceof ShowFrameTag){count++;if(count==%d)after=true;}}while(count<180){hold.addTag(new ShowFrameTag(swf));count++;}hold.setFrameCount(count);hold.resetTimeline();hold.setModified(true);}\n"%(int(sid),int(stop))
    filtered={k for k in keys if (rows[k].get("parent_placement")or{}).get("filters")}
    # Small bounded batches keep the original renderer's bitmap cache within2GB.
    for offset in range(0,len(keys),7):
        batch=keys[offset:offset+7]
        batch_setup=setup+(crt4_beast_mask_setup() if "crt4_y_beast"in batch else "")
        signature=hashlib.sha256(json.dumps({"specs":{k:specs[k]for k in batch},"setup":batch_setup,"renderer":shared.PLAYER_RENDERER},sort_keys=True).encode()).hexdigest()
        folder=TASK/"crt4_render"/signature[:20];cache=folder/"render.json"
        if cache.is_file():
            memo=json.loads(cache.read_text());folders={int(k):Path(v)for k,v in memo["folders"].items()};bounds={int(k):v for k,v in memo["bounds"].items()}
        else:
            folders,bounds=shared.render_default_player_frames(folder,batch,source_setup=batch_setup)
            cache.write_text(json.dumps({"signature":signature,"folders":{str(k):str(v)for k,v in folders.items()},"bounds":bounds}),encoding="utf-8")
        filtered_folders={};filtered_bounds={};filter_matrices={}
        chosen=[k for k in batch if k in filtered]
        if chosen:
            from render_act05_filtered import render_filtered
            wrap_specs={k:{"source_id":int(rows[k]["source_id"]),"parent_id":int(rows[k]["parent_id"]),"parent_source_frame":int(rows[k]["parent_source_frame"]),"depth":int(rows[k]["parent_placement"]["depth"]),"frames":list(specs[k][1]),"bake_basis":True}for k in chosen}
            wrapped=folder/"filtered";memo_path=wrapped/"filtered_provenance.json"
            if memo_path.exists():
                memo=json.loads(memo_path.read_text());filtered_bounds={k:v for k,v in memo["bounds"].items()};filter_matrices=memo["baked_matrices"]
                filtered_folders={k:next(p for p in (wrapped/k).iterdir()if p.is_dir()and p.name.startswith("DefineSprite_"))for k in chosen}
            else:
                java_helpers=shared.PLAYER_RENDERER.split("class PlayerRenderer {",1)[1].split(" public static void main",1)[0]
                filtered_folders,filtered_bounds=render_filtered(wrapped,wrap_specs,source_setup=batch_setup,java_helpers=java_helpers)
                filter_matrices=json.loads(memo_path.read_text())["baked_matrices"]
        symbols=shared.read_source_symbols({int(rows[k]["source_id"])for k in batch})
        # Validate selected output before creating any unregistered game asset.
        empty={}
        for key in batch:
            sid=int(rows[key]["source_id"]);empty[key]=all(Image.open(folders[sid]/f"{f}.png").convert("RGBA").getchannel("A").getbbox() is None for f in specs[key][1])
            if empty[key]:
                remaining=[r for f,rs in shared.source_frames(symbols[sid]).items()if f in specs[key][1] for r in rs.values()if int(r.get("characterId",-1))not in rows[key].get("remove_child_ids",[])]
                if any(int(r.get("colorTransform",{}).get("alphaMultTerm",256))!=0 for r in remaining):raise ValueError("Unexpected empty required CRT4 visual: "+key)
        for key in batch:
            spec=specs[key];sid=int(spec[0])
            render_folder=filtered_folders.get(key,folders[sid]);render_bounds={sid:filtered_bounds[key]}if key in filtered_bounds else bounds
            catalog["animations"][key]=shared.build_animation(key,spec,render_bounds,previous,provenance,render_folder,allow_empty=empty[key])
            if key in filter_matrices:
                color=(rows[key].get("parent_placement")or{}).get("color_transform")or{}
                catalog["animations"][key].update({"baked_placement_matrix":filter_matrices[key],"baked_alpha_mult":int(color.get("alphaMultTerm",256)),"original_parent_filter_baked":True})
            if key=="crt4_y_beast":catalog["animations"][key].update({"baked_placement_matrix":[1,0,0,1,-59.3,-99.8],"baked_alpha_mult":256,"source_mask_parent":907,"source_mask_shape":861,"source_mask_depth":1,"source_mask_clip_depth":30,"source_render_space":"original907 local; runtime inverse baked906 full placement once"})
            catalog["animations"][key].update({"render_profile":"act06_crt4_default_source","source_parent_matrix":rows[key]["parent_matrix"],"effective_parent_matrix":rows[key]["effective_parent_matrix"],"transparent_after_independent_split":empty[key],"sparse_visual_mapping":plan.get("sparse_visual_mapping",{}).get(key,{}),"source_part_offset_baked":bool(rows[key]["is_main"])})
            for directory in shared.SOURCES.joinpath("scripts").glob(f"DefineSprite_{sid}*"):
                if directory.name==f"DefineSprite_{sid}"or directory.name.startswith(f"DefineSprite_{sid}_"):provenance.extend(shared.source_record(p)for p in directory.rglob("*.as"))
        catalog["render_profiles"]["act06_crt4_default_source"]={"selector_pages":plan["selector_pages"],"independent_children_removed":plan["independent_children_removed"],"contract":"Main parent translation in pivot and diagonal scale once. Independent parts source-local; runtime owns original parent matrix and clocks. No independent fifth equipment family."}
        shared.act05_publish(catalog,provenance)
        print(json.dumps({"crt4_imported_batch":batch}),flush=True)
    reviewed={catalog["animations"][k]["output"]["path"]for k in keys}
    if any(shared.sha256(shared.PROJECT/p)!=h for p,h in before.items()if p not in reviewed):raise ValueError("CRT4 import changed unrelated output")

def import_crt4_geometry_audio() -> None:
    shared.verify_catalog()
    plan=json.loads((shared.PROJECT/"data/act06_crt4_import.json").read_text(encoding="utf-8"))
    rules=json.loads((shared.PROJECT/"data/act06_crt4_rules.json").read_text(encoding="utf-8"))
    catalog=json.loads(shared.CATALOG.read_text(encoding="utf-8"));previous={r["path"]:r["sha256"]for r in catalog["outputs"]};before=previous.copy()
    provenance=[shared.source_record(shared.SWF),shared.source_record(shared.SOURCES/"structure/game.xml")]
    body=json.loads(json.dumps(rules["body"]))
    for clip in body["clips"].values():
        clip["frame_count"]=max(map(int,clip["rects_by_source_frame"]),default=1)
        clip["stop_source_frame"]=max(map(int,clip.get("stop_frames",[])),default=clip["frame_count"])
    catalog["source_geometry"]["act06_crt4_body"]=body
    catalog["source_geometry"]["act06_crt4_hit_windows"]={"windows":rules["hit_windows"],"space":"owner-local source rectangles; main author parent matrix applied once by converter; world matrices applied by Battle"}
    catalog["source_geometry"]["act06_crt4_components"]={"components":plan["components_geometry"],"sparse_visual_mapping":plan["sparse_visual_mapping"],"visual_clock_reuse":plan["visual_clock_reuse"],"cutin_root_placements":catalog["source_geometry"]["act05_crt3_components"]["cutin"]["root_placements_by_source_frame"],"screen_feedback":json.loads((shared.PROJECT/"data/act05_crt3_feedback.json").read_text())}
    requested={6405,6406}
    wanted={6405:None,6406:{6405}}
    for row in plan["animations"].values():
        if row.get("parent_id") is not None:
            host=int(row["parent_id"]);requested.add(host)
            if host not in wanted:wanted[host]=set()
            if wanted[host] is not None:wanted[host].add(int(row["source_id"]))
    symbols=shared.read_source_symbols(requested)
    tracks={}
    for sid in requested:
        sparse=[];previous_rows=None
        for f,state in shared.source_frames(symbols[sid]).items():
            rows=[]
            for row in state.values():
                child=int(row.get("characterId",-1))
                if wanted[sid] is not None and child not in wanted[sid]:continue
                value={"source_id":child,"depth":int(row["depth"]),"matrix":shared.source_matrix(row.get("matrix",{})),"alpha_mult":int(row.get("colorTransform",{}).get("alphaMultTerm",256))}
                if row.get("name"):value["name"]=row["name"]
                if row.get("clipDepth"):value["clip_depth"]=int(row["clipDepth"])
                rows.append(value)
            if rows!=previous_rows:sparse.append({"source_frame":f,"placements":rows});previous_rows=rows
        tracks[str(sid)]=sparse
    catalog["source_geometry"]["act06_crt4_components"]["action_tracks"]=tracks
    fx=body["player_hit_fx"]
    catalog["source_geometry"]["player_hit_fx"]["crt_4"]={"source_id":4689,"animation":"player_hit_fx","offset_px":fx["parents"]["169"]["matrix"][4:],"offset_by_parent":{k:v["matrix"][4:]for k,v in fx["parents"].items()},"source_parent":6732,"source_parent_frames":[169,170],"basis_and_filter_already_baked":True,"conversion":"Exact original basis/filter equal existing4689 parent4686/2; apply only parent-specific translation and outer actor transform."}
    existing={int(v["source"]["character_id"]):v for v in catalog["audio_records"].values()if v.get("source",{}).get("character_id")is not None}
    for sid,events in rules["source_audio"].items():
        for source in events:
            sound_id=int(source["sound_id"])
            record=existing.get(sound_id)
            if record is None:
                record=shared.act05_sound_asset(sound_id,previous,provenance);existing[sound_id]=record
            else:provenance.append(record["source"])
            info=source["sound_info"];alias=source["alias"]
            event={"sprite_id":int(sid),"frame":int(source["source_frame"]),"sound_id":sound_id,"in_point_samples_44100":int(info.get("inPoint",0)),"source_sound_info":info,"envelope":[{"sample":int(v["pos44"]),"left":int(v["leftLevel"]),"right":int(v["rightLevel"])}for v in info.get("envelopes",[])]}
            if info.get("hasOutPoint")=="true":event["out_point_samples_44100"]=int(info["outPoint"])
            if info.get("hasLoops")=="true":event["loop_count"]=int(info["loopCount"])
            catalog["audio"]["sfx"][alias]=record["path"];catalog["audio_records"][alias]=record;catalog["audio_events"][alias]=event
    def collect(value):
        if isinstance(value,dict):
            if isinstance(value.get("path"),str) and value["path"].startswith("res/"):
                path=shared.WORKSPACE/value["path"]
                if path.is_file():provenance.append(shared.source_record(path))
            for item in value.values():collect(item)
        elif isinstance(value,list):
            for item in value:collect(item)
    collect(rules)
    shared.act05_publish(catalog,provenance)
    if any(shared.sha256(shared.PROJECT/p)!=h for p,h in before.items()):raise ValueError("CRT4 geometry/audio changed an existing output")
    print(json.dumps({"crt4_audio_events":sum(map(len,rules["source_audio"].values())),"crt4_body_clips":len(body["clips"]),"existing_outputs_unchanged":len(before)}))

def import_crt4_nested() -> None:
    # Only newly selected CRT4 assets; the prior four characters stay byte-identical.
    import_crt4_animations(["crt4_ghostwalk","crt4_ghostwalk_loop","crt4_clone_status"])
    import_crt4_geometry_audio()
    catalog=json.loads(shared.CATALOG.read_text(encoding="utf-8"));previous={r["path"]:r["sha256"]for r in catalog["outputs"]}
    rules=json.loads((shared.PROJECT/"data/act06_crt4_rules.json").read_text(encoding="utf-8"))
    sound=rules["named_common_slash"]["sound"];alias="crt4_script_common_contact_sound5"
    provenance=[shared.source_record(shared.SWF),shared.source_record(shared.SOURCES/"structure/game.xml")]
    provenance.extend(shared.source_record(shared.WORKSPACE/row["path"])for row in sound["source"])
    record=shared.act05_sound_asset(int(sound["sound_id"]),previous,provenance)
    catalog["audio"]["sfx"][alias]=record["path"];catalog["audio_records"][alias]=record
    catalog["audio_events"][alias]={"sprite_id":1481,"frame":1,"sound_id":5,"script_sound":True,"linkage":sound["linkage"],"source_crt":4,"in_point_samples_44100":0,"scope":"Original1481/1489/1496 frame1 branch; common slash source-world instance, not every air X"}
    catalog["source_geometry"]["act06_crt4_components"]["named_common_slash"]=rules["named_common_slash"]
    shared.act05_publish(catalog,provenance)
    if any(shared.sha256(shared.PROJECT/p)!=h for p,h in previous.items()):raise ValueError("CRT4 script sound import changed existing output")

def main() -> None:
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--crt3-waves", action="store_true")
    parser.add_argument("--crt4-ui", action="store_true")
    parser.add_argument("--crt4-animations",nargs="+")
    parser.add_argument("--crt4-geometry",action="store_true")
    parser.add_argument("--crt4-nested",action="store_true")
    args=parser.parse_args()
    if args.crt3_waves:import_crt3_waves()
    elif args.crt4_ui:import_crt4_ui()
    elif args.crt4_animations:import_crt4_animations(args.crt4_animations)
    elif args.crt4_geometry:import_crt4_geometry_audio()
    elif args.crt4_nested:import_crt4_nested()
    else:parser.error("Choose an explicitly reviewed subset")

if __name__ == "__main__":main()
