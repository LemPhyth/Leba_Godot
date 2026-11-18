"""Read controlled Ruffle collision/observer probes; no game or source mutations.

Enemy-contact probes use real original hitTest after explicitly positioning actors
and seeking enemy attack clips. Hit-observer probes directly seek player clips.
Neither is natural keyboard gameplay or native Adobe Flash evidence.
"""
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

from analyze_action_probe import PROJECT, WORKSPACE, DONE, numeric_changes, parse_fields, sha256

PREFIX = re.compile(r"avm_trace:\s+(LEIBA02_DETAIL|LEIBA02|LEIBA_CONTACT_FIXTURE|LEIBA_HIT_FIXTURE|LEIBA_CONTACT)\|")
ROOT = WORKSPACE / "tools/swf/runtime_probe"
FIELDS = ("t", "root", "crt", "nan", "actor", "action", "hurt", "hp", "ehp", "enemy", "outer", "overlap")


def read_probe(directory: Path, done_tick: int) -> dict:
    log = directory / "run1/log/ruffle.log"
    raw = log.read_bytes()
    samples, interventions, done_lines, duplicates, runtime_errors = {}, [], [], [], []
    for line_no, line in enumerate(raw.decode("utf-8-sig", errors="replace").splitlines(), 1):
        if " ERROR " in line:
            runtime_errors.append({"line": line_no, "text": line})
        if DONE.search(line):
            done_lines.append(line_no)
            continue
        match = PREFIX.search(line)
        if match is None:
            continue
        data = parse_fields(line[match.end():])
        tick = data.get("t")
        if not isinstance(tick, int):
            continue
        if match[1].endswith("FIXTURE"):
            interventions.append({**data, "log_line": line_no})
            continue
        kind = {"LEIBA02":"base", "LEIBA02_DETAIL":"detail", "LEIBA_CONTACT":"contact"}[match[1]]
        if "overlap" in data:
            data["overlap"] = {"true":True, "false":False}.get(data["overlap"], data["overlap"])
        row = samples.setdefault(tick, {"records":{}, "log_lines":[]})
        if kind in row["records"]:
            duplicates.append({"tick":tick, "kind":kind, "log_line":line_no})
        row["records"][kind] = data
        row["log_lines"].append(line_no)
    merged = {tick: {**row["records"].get("base",{}), **row["records"].get("detail",{}),
                     **row["records"].get("contact",{}), "log_lines":row["log_lines"]}
              for tick, row in samples.items()}
    missing = [tick for tick in range(30, done_tick+1) if tick not in samples or
               not {"base", "detail"}.issubset(samples[tick]["records"])]
    provenance = json.loads((directory / "provenance.json").read_text(encoding="utf-8"))
    observer_sha = sha256((directory / "observer.as").read_bytes())
    return {"complete":bool(done_lines) and not missing and not duplicates and observer_sha == provenance["observer_sha256"],
            "done_expected_tick":done_tick, "done_marker_lines":done_lines,
            "missing_base_or_detail_ticks":missing, "duplicates":duplicates,
            "log_snapshot":{"path":str(log.resolve()), "bytes":len(raw), "sha256":sha256(raw)},
            "provenance":provenance, "observer_sha256":observer_sha,
            "runtime_log_errors":runtime_errors, "interventions":interventions, "samples":merged}


def case(probe: dict, name: str, start: int, until: int) -> dict:
    samples = probe["samples"]
    rows = [samples[tick] for tick in range(start, until) if tick in samples]
    return {"name":name, "from_tick":start, "until_exclusive":until,
            "hp_changes":numeric_changes(rows, "hp", samples.get(start-1)),
            "overlap_ticks":[row["t"] for row in rows if row.get("overlap") is True],
            "actor_sequence":[row.get("actor","missing") for row in rows],
            "hurt_sequence":[row.get("hurt","missing") for row in rows],
            "timeline":[{field:row.get(field,"not_logged") for field in FIELDS} |
                        {"log_lines":row["log_lines"]} for row in rows],
            "interventions":[event for event in probe["interventions"] if start <= event["t"] < until]}


def analyze(root: Path) -> dict:
    contacts, comparison = [], []
    for nan in range(3):
        probe = read_probe(root / f"leiba02_contact_nan{nan}",180)
        cases = [case(probe,"root6_attack68_contact",55,80), case(probe,"root2_attack26_contact",135,160)]
        for item in cases:
            comparison.append({"nan":nan, "case":item["name"], "overlap_ticks":item["overlap_ticks"], "hp_changes":item["hp_changes"]})
        contacts.append({key:value for key,value in probe.items() if key != "samples"} | {"cases":cases})
    observer = read_probe(root / "leiba02_hit_fixture",220)
    observer_cases = [case(observer,"root4_hurt_and_same_parent_goto",58,85),
                      case(observer,"root4_hurt_after_one_enemy_internal_death",100,130),
                      case(observer,"root6_repeated_explicit_hurt_seek2",178,200)]
    return {"schema_version":1, "complete":all(item["complete"] for item in contacts) and observer["complete"],
            "evidence_kind":"controlled_Ruffle_original_collision_and_direct_clip_fixtures_NOT_natural_keyboard",
            "source_fps":25, "contacts":contacts, "comparison":comparison,
            "observers":{key:value for key,value in observer.items() if key != "samples"} | {"cases":observer_cases},
            "limitations":[
                "Positions and enemy action frames are injected; the original collision scripts then run. This does not validate natural encounter AI or keyboard operation.",
                "Observer fixtures explicitly goto player hit, seek hurt2 and set one root4 enemy HP to zero; they are separate from collision cases.",
                "Base/detail/contact are observer samples after fixture code; within-tick listener order must be inferred carefully.",
                "Missing contact records mean no contact record was emitted, not automatically overlap=false.",
                "Nonfatal Ruffle runtime log errors are retained in metadata; DONE and frame coverage establish only fixture completion, not whole-game compatibility.",
            ]}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--probe-root",type=Path,default=ROOT)
    parser.add_argument("--output",type=Path,default=PROJECT / "artifacts/leiba02_20261112/hit_probe.json")
    args = parser.parse_args()
    if args.output.resolve().is_relative_to(args.probe_root.resolve()):
        parser.error("Derived output must stay outside the read-only probe input tree.")
    result = analyze(args.probe_root)
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(result,ensure_ascii=False,indent=2,allow_nan=False)+"\n",encoding="utf-8")
    print(json.dumps({"complete":result["complete"], "output":str(args.output)}))
    for item in result["comparison"]:
        print(json.dumps(item))
    for item in result["observers"]["cases"]:
        print(json.dumps({"case":item["name"], "hp_changes":item["hp_changes"]}))


if __name__ == "__main__":
    main()
