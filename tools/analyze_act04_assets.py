"""Read-only ACT04 source/derived-resource audit. Writes only the named artifact."""
from __future__ import annotations
import argparse
import json
import tempfile
from pathlib import Path
import import_runtime_assets as assets


def audit(output: Path) -> dict:
    catalog=json.loads(assets.CATALOG.read_text(encoding="utf-8"))
    baseline=json.loads((assets.PROJECT/"artifacts/leba_act04_20261117/investigation/assets_baseline.json").read_text(encoding="utf-8"))
    allowed={"assets/atlases/crt1_q_buff_ring.png","assets/atlases/crt1_q_buff_cloud.png"}
    changes=[row["path"] for row in baseline["outputs"] if assets.sha256(assets.PROJECT/row["path"])!=row["sha256"]]
    added=[row for row in catalog["outputs"] if row["path"] not in {v["path"] for v in baseline["outputs"]}]
    report={"baseline_outputs":len(baseline["outputs"]),"unchanged_original_outputs":len(baseline["outputs"])-len(changes),"reviewed_q_filter_corrections":[p for p in changes if p in allowed],"unexpected_original_changes":[p for p in changes if p not in allowed],"added_outputs":added,"crt2_animations":{k:{"source_sprite_id":v["source_sprite_id"],"source_frames":[f["source_frame"]for f in v["frames"]],"parent_offset_px":v.get("parent_offset_px"),"parent_scale":v.get("parent_scale"),"render_profile":v.get("render_profile")}for k,v in catalog["animations"].items()if k.startswith("crt2_")},"source_rules":"AS/XML/static rendering only. This audit does not certify runtime collisions, independent-clock execution or audible playback."}
    output=output.resolve()
    if not output.is_relative_to((assets.PROJECT/"artifacts").resolve()):raise ValueError("Audit output must stay in project artifacts")
    output.parent.mkdir(parents=True,exist_ok=True)
    output.write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    return report


def check_renders(keys: list[str], output: Path) -> dict:
    """Re-render source frames into temporary storage; never touch asset files."""
    catalog=json.loads(assets.CATALOG.read_text(encoding="utf-8"));checks=[]
    groups={}
    for key in keys:
        if key not in catalog["animations"] or key not in assets.ANIMATIONS:raise ValueError(f"Unknown animation {key}")
        profile=catalog["animations"][key].get("render_profile","")
        page=2 if profile=="act04_pren_source" else 1 if profile=="act04_default_source" else 0
        groups.setdefault(page,[]).append(key)
    for page,selected in groups.items():
        with tempfile.TemporaryDirectory(prefix="leba_act04_readonly_render_audit_")as temp:
            folders,bounds=assets.render_default_player_frames(Path(temp),selected,crt2_page=page)
            for key in selected:
                animation=catalog["animations"][key];ident=animation["source_sprite_id"]
                mismatch=[int(f)for f,digest in animation["rendered_frames_sha256"].items()if assets.sha256(folders[ident]/f"{f}.png")!=digest]
                checks.append({"animation":key,"source_frames_checked":len(animation["frames"]),"pixel_hash_mismatches":mismatch,"bounds_equal":bounds[ident]==animation["source_bounds"]})
    result={"method":"FFDec in-memory source rerender into temporary folder; no catalog/assets mutation","checks":checks,"passed":all(not v["pixel_hash_mismatches"]and v["bounds_equal"]for v in checks)}
    output=output.resolve()
    if not output.is_relative_to((assets.PROJECT/"artifacts").resolve()):raise ValueError("Render audit output must stay in artifacts")
    output.write_text(json.dumps(result,ensure_ascii=False,indent=2)+"\n",encoding="utf-8");return result


if __name__=="__main__":
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output",type=Path,default=assets.PROJECT/"artifacts/leba_act04_20261117/investigation/assets_audit.json")
    parser.add_argument("--check-renders",nargs="+",help="Read-only exact source-PNG rerender checks, no asset writes")
    args=parser.parse_args()
    if args.check_renders:
        result=check_renders(args.check_renders,args.output);print(json.dumps(result));raise SystemExit(not result["passed"])
    result=audit(args.output)
    print(json.dumps({"baseline_outputs":result["baseline_outputs"],"unchanged":result["unchanged_original_outputs"],"q_corrections":result["reviewed_q_filter_corrections"],"unexpected":result["unexpected_original_changes"],"added":len(result["added_outputs"])}))
    raise SystemExit(bool(result["unexpected_original_changes"]))
