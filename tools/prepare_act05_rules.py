"""Explicitly assemble reviewed CRT3 source facts, never mutate author resources."""
import json,copy,sys
from pathlib import Path
import import_runtime_assets as source
P=Path(__file__).resolve().parents[1]
R=P/"artifacts/leba_act05_20261117/investigation"
def prune(v):
 if isinstance(v,list):return[prune(x)for x in v]
 if not isinstance(v,dict):return v
 return{k:prune(x)for k,x in v.items()if k not in("source_paths","slot_source_paths","evidence","main_source_audio","sound_info_xml","control_events","text","filters_xml","raw_source_graph","source_hashes","script")}
def main():
 if "--prepare"not in sys.argv:raise SystemExit(2)
 a=json.loads((R/"crt3_actions.json").read_text(encoding="utf8"));s=json.loads((R/"crt3_special.json").read_text(encoding="utf8"));plan=json.loads((R/"act05_import_plan.json").read_text(encoding="utf8"))
 if (P/"data/act05_crt3_feedback.json").exists():
  for key,sid,seq in [("crt3_e_map_dark",1410,list(range(1,28))),("crt3_e_screen_flash",6861,[1,22,23])]:
   plan["ACT05_ANIMATIONS"][key]=[sid,seq,False,[0,0],None,None];plan["parent_scales"][key]=[1,1];plan["weapon_shape_selector"]["render_page_by_source_frame"][key]={str(f):1 for f in seq}
 actions=copy.deepcopy(a["actions"])
 for i,row in enumerate(s["combo"]["actions"]):
  sid=row["source_id"];ident=(["basic","basic2","basic3","skill_s","skill_s2","skill_s3"])[i]
  actions[ident]={"id":ident,"source_id":sid,"source_parent":row["parent_frame"],"sequence":list(range(row["default_frames"][0],row["default_frames"][1]+1)),"mp_cost":0,"hp_cost":0,"cubes":0,"cooldown_ticks":0,"input":"attack"if i==0 else"skill_s"if i==3 else None,"allowed_states":["idle","move","attack"],"allowed_parents":[101,102,103,106,107,108,117,118,119],"next":"idle","events":[],"branches":[],"source":"Original actor6732 parent%d and sprite%d"%(row["parent_frame"],sid)}
 symbols=source.read_source_symbols({6732,6155,6177,6300,4259,4263,4266})
 for ident,sid,parent,slot,cost,cubes,end,inp in[("skill_h",6155,129,4259,5,0,19,"load_h"),("skill_w",6177,131,4263,8,2,84,"skill_w"),("skill_e",6300,132,4266,30,5,10,"skill_e")]:
  actions[ident]={"id":ident,"source_id":sid,"source_parent":parent,"sequence":list(range(1,end+1)),"mp_cost":cost,"hp_cost":0,"cubes":cubes,"cooldown_ticks":len(source.source_frames(symbols[slot]))-1,"slot_id":slot,"input":inp,"allowed_states":["idle","move","attack"],"allowed_parents":[101,102,103,106,107,108,117,118,119],"next":"idle","events":[],"branches":[],"source":"Original6732/%d, sprite%d, slot%d"%(parent,sid,slot)}
 for ident,row in actions.items():
  # One selected main atlas may serve multiple branches of the same sprite.
  candidates=[k for k,v in plan["ACT05_ANIMATIONS"].items()if v[0]==row["source_id"]and v[4]==6732]
  if not candidates:raise ValueError("No curated main atlas: "+ident)
  row["animation_key"]=candidates[0]
  placement=next(v for v in source.source_frames(symbols[6732])[row["source_parent"]].values()if v.get("characterId")==str(row["source_id"]))
  row["parent_matrix"]=source.source_matrix(placement.get("matrix",{}))
 actions["skill_e"]["hold_at"]=[10];actions["skill_e"]["hold"]=True;actions["skill_e"]["cooldown_deferred"]=True
 actions["jump_z"]["cooldown_deferred"]=True
 actions["skill_a"]["input_aliases"]=["skill_a","skill_z"]
 result=prune(a);result["actions"]=prune(actions);result["components"].update({"combo":prune(s["combo"]),"overdrive":prune(s["H"]),"awakening_default":prune(s["E"]),"source_audio":prune(s["audio"])})
 result["independent_windows"]=[]
 for item in s.get("hit_windows_spec",[]):
  row={"source_id":item["clock_source_id"],"helper_id":item["helper_source_id"],"depth":item["depth"],"active_source_frames":item["active_frames"],"active_frames":[min(item["active_frames"]),max(item["active_frames"])],"default_rule":prune(item["default_rule"]),"matrix":item.get("placement",{}).get("matrix",[1,0,0,1,0,0])}
  if any(a["source_id"]==row["source_id"]for a in actions.values()):result["hit_windows_source"].append(row)
  else:result["independent_windows"].append(row)
 main_sources={a["source_id"]for a in actions.values()}
 base=result["hit_windows_source"]
 result["hit_windows_source"]=[row for row in base if row["source_id"]in main_sources]
 for row in base:
  if row["source_id"]not in main_sources:
   row.setdefault("active_source_frames",list(range(int(row["active_frames"][0]),int(row["active_frames"][-1])+1)))
   result["independent_windows"].append(row)
 result["components"]["w_control"]=prune(s.get("W",{}))
 # Narrow source review corrections: G source40 explicitly +=0.1; the
 # Q-finisher callbacks for enemies2..5 still address source enemy1's status.
 for window in result["hit_windows_source"]:
  rule=window["default_rule"]
  if window["source_id"]==6124 and window["active_frames"][0]==40:rule["gravity_acceleration_add"]=0.1
  if window["source_id"]==6142 and "status"in rule:rule["status_target"]="first_source_enemy"
 for row in result["actions"].values():
  row["source"]="Original AS/XML sprite%d parent%d; source hashes in asset_catalog and investigation facts."%(row["source_id"],row["source_parent"])
 (P/"data/act05_crt3_rules.json").write_text(json.dumps(result,ensure_ascii=False,indent=2)+"\n",encoding="utf8")
 (P/"data/act05_crt3_import.json").write_text(json.dumps(plan,ensure_ascii=False,indent=2)+"\n",encoding="utf8")
 print("Reviewed ACT05 facts prepared",len(actions))
if __name__=="__main__":main()
