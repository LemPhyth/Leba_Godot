"""Read M1 Ruffle snapshots without launching a game or changing source files.

The basics fixture's attempted Key.isDown override is not verified input.
Keep source records, missing values, callback sampling and host key contamination
explicit. This report is original evidence, not a Godot regression result.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import re
from pathlib import Path

PROJECT = Path(__file__).resolve().parents[1]
WORKSPACE = PROJECT.parent
PROBES = WORKSPACE / "tools/swf/runtime_probe"
DEFAULT_BASIC = PROBES / "leba_act01_basics_20261113/run1/log/ruffle.log"
DEFAULT_NATIVE = PROBES / "leba_act01_native_20261113/run1/log/ruffle.log"
DEFAULT_HELD = PROBES / "leba_act01_held_20261114/run1/log/ruffle.log"
DEFAULT_OUTPUT = PROJECT / "artifacts/leba_act01_20261113/controlled_basics.json"
DEFAULT_NATIVE_HELD_OUTPUT = PROJECT / "artifacts/leba_act01_20261114/held_native.json"
TRACE = re.compile(r"avm_trace:\s+(LE(?:IBA|BA)[A-Z0-9_]*)(?:\||$)")
SCHEDULE = [
    ("c_no_input", 80, 125, 95), ("c_attempted_right", 125, 170, 95),
    ("c_attempted_x", 170, 215, 95), ("c_attempted_x_left", 215, 260, 95),
    ("down_facing_right", 260, 290, 12), ("down_facing_left", 290, 320, 12),
    ("z_parent5", 320, 355, 5), ("z_parent6", 355, 390, 6),
]


def digest(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def value(raw: str):
    try:
        number = float(raw)
    except ValueError:
        return raw
    if not math.isfinite(number):
        return raw
    return int(number) if number.is_integer() else number


def fields(payload: str) -> dict:
    return {k: value(v) for k, v in (p.split("=", 1) for p in payload.split("|") if "=" in p)}


def read_snapshot(path: Path, sample_prefix: str) -> dict:
    raw = path.read_bytes()  # Parse and hash exactly the same snapshot, even if still appending.
    by_tick, keys, shots, duplicates, done, warnings, calls, installs = {}, [], [], [], [], [], [], []
    previous_tick = None
    for line_number, line in enumerate(raw.decode("utf-8-sig", errors="replace").splitlines(), 1):
        if " WARN " in line or " ERROR " in line:
            warnings.append({"line": line_number, "text": line})
        match = TRACE.search(line)
        if not match:
            continue
        prefix = match[1]
        data = fields(line[match.end():])
        timestamp = line.split(" ", 1)[0]
        if prefix in ("LEIBA_FIXTURE_DONE", "LEBA_M1_SHADOW_DONE", "LEBA_M1_NATIVE_HELD_DONE"):
            done.append({**data,"line": line_number, "previous_observer_tick": previous_tick})
        elif prefix == "LEBA_M1_NATIVE_HELD_INSTALL":
            installs.append({**data,"line":line_number,"timestamp":timestamp})
        elif prefix in ("LEBA_M1_SHADOW_CALL", "LEBA_M1_NATIVE_HELD_CALL"):
            calls.append({**data,"line":line_number,"timestamp":timestamp})
        elif prefix == "LEIBA02_KEY":
            keys.append({**data, "line": line_number, "timestamp": timestamp,
                         "previous_observer_tick": previous_tick})
        elif prefix in ("LEBA_M1_SHOTS", "LEBA_M1_SHADOW_SHOTS"):
            shots.append({**data, "line": line_number, "timestamp": timestamp})
        elif prefix in (sample_prefix, "LEIBA02", "LEIBA02_DETAIL"):
            tick = data.get("t")
            if not isinstance(tick, int):
                raise ValueError(f"Malformed tick at {path}:{line_number}")
            previous_tick = tick
            records = by_tick.setdefault(tick, {})
            if prefix in records:
                duplicates.append({"t": tick, "prefix": prefix, "line": line_number})
            records[prefix] = {**data, "log_line": line_number, "timestamp": timestamp}
    rows = {}
    for tick, records in by_tick.items():
        if sample_prefix not in records:
            continue
        row = {**records.get("LEIBA02", {}), **records.get("LEIBA02_DETAIL", {}),
               **records[sample_prefix]}
        row["record_lines"] = {k: r["log_line"] for k, r in records.items()}
        xmin, xmax = row.get("body_xmin"), row.get("body_xmax")
        if isinstance(xmin, (float, int)) and isinstance(xmax, (float, int)):
            row["observed_body_width"] = round(xmax - xmin, 8)
        rows[tick] = row
    for key in keys:
        following = next((row for row in rows.values() if row["log_line"] > key["line"]), None)
        key["next_sample_tick"] = following["t"] if following else None
    folder = path.parents[2]
    provenance_path, observer_path = folder / "provenance.json", folder / "observer.as"
    provenance = json.loads(provenance_path.read_text(encoding="utf-8"))
    observer_raw = observer_path.read_bytes()
    return {"rows": rows, "records": by_tick, "keys": keys, "shots": shots,"calls":calls,"installs":installs,
            "duplicate_records": duplicates, "done": done, "warnings": warnings,
            "log_snapshot": {"path": str(path.resolve()), "bytes": len(raw), "sha256": digest(raw)},
            "provenance": provenance,
            "observer": {"path": str(observer_path), "sha256": digest(observer_raw),
                         "matches_provenance": digest(observer_raw) == provenance["observer_sha256"]}}


def delta(a, b):
    return round(b - a, 10) if isinstance(a, (int, float)) and isinstance(b, (int, float)) else None


def summarize_case(snapshot: dict, name: str, start: int, until: int, parent: int) -> dict:
    all_rows = snapshot["rows"]
    rows = [all_rows[t] for t in range(start, until) if t in all_rows]
    return_row = next((r for r in rows if r["t"] > start and r.get("parent") == 1), None)
    active = [r for r in rows if return_row is None or r["t"] < return_row["t"]]
    timeline, previous = [], all_rows.get(start - 1)
    for row in rows:
        timeline.append({**row, "root_dx_since_previous_sample": delta(previous.get("px"), row.get("px")) if previous else None})
        previous = row
    positions = sorted({r["px"] for r in active if isinstance(r.get("px"), (int, float))})
    child_field = "move" if parent in (6, 12) else "child"
    required = {"LEBA_M1", "LEIBA02", "LEIBA02_DETAIL"}
    missing = [t for t in range(start, until) if not required.issubset(snapshot["records"].get(t, {}))]
    return {"case": name, "fixture_start_tick": start, "until_exclusive": until,
            "declared_fixture_operation": f"player.gotoAndStop({parent})",
            "observed_start": rows[0] if rows else None,
            "first_return_idle_tick": return_row["t"] if return_row else None,
            "source_tick_intervals_to_return": return_row["t"] - start if return_row else None,
            "observed_child_field": child_field,
            "observed_child_sequence_before_return": [r.get(child_field, "missing") for r in active],
            "observed_body_sequence_before_return": [r.get("body", "missing") for r in active],
            "observed_air_subframes": sorted({r["sub"] for r in active if isinstance(r.get("sub"), int)}),
            "observed_active_root_positions": positions,
            "root_dx_entry_to_return": delta(rows[0].get("px"), return_row.get("px")) if rows and return_row else None,
            "observed_return": return_row,
            "shot_records": [r for r in snapshot["shots"] if start <= r.get("t", -1) < until],
            "missing_record_ticks": missing, "timeline": timeline}


def native_z_cases(snapshot: dict) -> list[dict]:
    result = []
    for event in snapshot["keys"]:
        if event.get("code") != 90 or event["next_sample_tick"] is None:
            continue
        start = event["next_sample_tick"]
        before = snapshot["rows"].get(event["previous_observer_tick"])
        rows = [snapshot["rows"][t] for t in range(start, start + 30) if t in snapshot["rows"]]
        if not rows:
            continue
        returned = next((r for r in rows[1:] if r.get("parent") == 1), None)
        stop = returned["t"] if returned else start + 29
        active = [r for r in rows if r["t"] <= stop]
        mp_steps = [delta(a.get("mp"), b.get("mp")) for a, b in zip(active, active[1:])]
        observed_regen = sorted({step for step in mp_steps if step is not None and step > 0})
        raw_mp_change = delta(before.get("mp"), rows[0].get("mp")) if before else None
        result.append({"event": event, "before_event": before, "first_sample_after_event": rows[0],
                       "first_return_idle_tick": returned["t"] if returned else None,
                       "root_dx_before_event_to_return": delta(before.get("px"), returned.get("px")) if before and returned else None,
                       "observed_mp_delta_at_first_sample": raw_mp_change,
                       "observed_later_positive_mp_steps": observed_regen,
                       "cost_if_one_observed_regeneration_step_occurred": round(observed_regen[0]-raw_mp_change,10) if len(observed_regen)==1 and raw_mp_change is not None else None,
                       "cost_status": "inference combining observed net MP change with subsequent regeneration; AS input script separately establishes cost3",
                       "child_frame1_observed": any(r.get("child") == 1 for r in active),
                       "timeline": active,
                       "limitations": ["Key records contain code but no tick; before/after sample ticks bracket the event, not an invented exact input tick.",
                                       "Startup was controlled; earlier host A/W/right-arrow key events remain in the session.",
                                       "No key-up records or complete held-key snapshot; do not infer input exclusivity or cooldown from zc=undefined."]})
    return result


def analyze_shadow(path: Path) -> dict:
    if not path.exists():
        return {"status":"not_run_or_log_missing","path":str(path)}
    source=read_snapshot(path,"LEBA_M1_SHADOW")
    rows=source["rows"]
    missing=[t for t in range(40,300) if t not in rows]
    complete=not missing and bool(source["done"]) and source["observer"]["matches_provenance"] and not source["duplicate_records"]
    global_unchanged=bool(rows) and all(r.get("global_unchanged") in ("true",True) for r in rows.values())
    counters=sorted({r.get("mock_total") for r in rows.values() if isinstance(r.get("mock_total"),int)})
    self_true=[r["t"] for r in rows.values() if r.get("visible39")=="true" or r.get("visible88")=="true"]
    ground=[rows[t] for t in range(60,81) if t in rows]
    positions=sorted({r["px"] for r in ground})
    jump_sequences=[]
    for start,end in ((110,145),(160,195),(210,245),(250,285)):
        sampled=[rows[t] for t in range(start,end) if t in rows]
        jump_sequences.append({"range":[start,end-1],"root_positions":sorted({r["px"] for r in sampled}),
                               "air_subframes":sorted({r["sub"] for r in sampled if isinstance(r.get("sub"),int)})})
    no_effect=complete and counters==[0] and not source["calls"] and not source["shots"] and len(positions)==1 and bool(self_true)
    launch_path=path.parents[1]/"launch.json"
    return {"status":"failed_to_drive_original_polling" if no_effect else "inconclusive_review_trace",
            "complete":complete,"missing_ticks":missing,"log_snapshot":source["log_snapshot"],
            "observer":source["observer"],"provenance":source["provenance"],
            "launch":json.loads(launch_path.read_text(encoding="utf-8-sig")) if launch_path.exists() else None,
            "done":source["done"],"global_unchanged_all_samples":global_unchanged,
            "observed_mock_total_values":counters,"non_probe_call_trace_count":len(source["calls"]),
            "self_query_true_ticks":self_true,"ground_window_root_positions":positions,
            "jump_windows":jump_sequences,"shot_records":source["shots"],
            "conclusion":"Self-queries resolve the shadow and return true, but non-probe calls stay zero and original movement/air fire do not happen. Shadowing has not reached the target original polling. No successful input evidence and no further automatic attempts.",
            "limitations":["Counter scope excludes fixture self-queries; counter interval ends at the following fixture invocation.",
                           "No function replacement or actor movement/fire was recorded; precise AVM1 scope/builtin dispatch mechanism remains unknown.",
                           "Controlled parent goto and enemy x900/player position resets are deliberate interventions, not natural gameplay."],
            "warnings":source["warnings"],"timeline":list(rows.values())}


def analyze_native_held(path: Path) -> dict:
    """Analyze the verified READ_ONLY-clearing fixture separately from failed runs."""
    source=read_snapshot(path,"LEBA_M1_NATIVE_HELD")
    rows=source["rows"]
    missing=[t for t in range(40,300) if t not in rows]
    complete=not missing and len(source["done"])==1 and len(source["installs"])==1 and source["observer"]["matches_provenance"] and not source["duplicate_records"]
    is_true=lambda item,key:item.get(key) in (True,"true")
    restored=bool(source["done"]) and all(is_true(source["done"][0],key) for key in ("object_same","original_restored","read_only_restored","root_key_unchanged"))
    original_calls=[c for c in source["calls"] if c.get("answer")=="true"]
    method_all=bool(rows) and all(is_true(r,"method_is_mock") and is_true(r,"object_same") and r.get("this_mismatch")==0 for r in rows.values())
    for row in rows.values():
        row["projectiles"]=[]
        for shot in str(row.get("shots","")).split(","):
            if not shot:continue
            name,frame,x,y=shot.split(":")
            row["projectiles"].append({"name":name,"frame":value(frame),"x":value(x),"y":value(y)})
        previous=rows.get(row["t"]-1)
        row["root_dx_since_previous_sample"]=delta(previous.get("px"),row.get("px")) if previous else None
    ground=[]
    for name,start,end in (("right",50,60),("both",60,70),("left",70,80)):
        seq=[rows[t] for t in range(start,end+1) if t in rows]
        ground.append({"case":name,"held_input_ticks":[start,end-1],"position_sample_ticks":[start,end],
                       "root_dx":delta(seq[0]["px"],seq[-1]["px"]) if seq else None,
                       "step_deltas":[delta(a["px"],b["px"]) for a,b in zip(seq,seq[1:])],
                       "facing_at_final_sample":seq[-1].get("face") if seq else None,"timeline":seq})
    jumps=[]
    for name,start,end in (("jump_x",110,145),("jump_x_reverse_left",165,200),("jump_x_reverse_right",220,255)):
        seq=[rows[t] for t in range(start,end+1) if t in rows]
        active=[r for r in seq if r.get("parent")==95]
        returned=next((r for r in seq if r["t"]>start and r.get("parent")!=95),None)
        spawns=[]
        for a,b in zip(active,active[1:]):
            if isinstance(a.get("sub_i"),int) and isinstance(b.get("sub_i"),int) and b["sub_i"]>a["sub_i"]:
                spawns.append({"sample_tick":b["t"],"callback_interval_after_tick":a["t"],
                               "parent_source_frame":b["child"],"air_source_frame":b["sub"],
                               "source_counter_delta":b["sub_i"]-a["sub_i"],
                               "projectiles_at_frame1":[s for s in b["projectiles"] if s["frame"]==1],
                               "log_line":b["log_line"]})
        jumps.append({"case":name,"sample_ticks":[start,end],"active_parent_source_frames":[r.get("child") for r in active],
                      "air_sequence":[{"t":r["t"],"parent_frame":r.get("child"),"sub":r.get("sub"),"sub_i":r.get("sub_i"),"x":r.get("px"),"dx":r["root_dx_since_previous_sample"]} for r in active if isinstance(r.get("child"),int) and r["child"]>=15],
                      "source_counter_confirmed_shot_count":sum(s["source_counter_delta"] for s in spawns),"spawn_samples":spawns,
                      "root_dx_to_last_air_sample":delta(active[0]["px"],active[-1]["px"]) if active else None,
                      "return_sample":returned,"timeline":seq,
                      "source_poll_calls":[c for c in source["calls"] if start<=c.get("t",-1)<end]})
    shot_total=sum(c["source_counter_confirmed_shot_count"] for c in jumps)
    effective=complete and restored and method_all and bool(original_calls) and any(c["root_dx"]!=0 for c in ground) and shot_total>0
    launch_path=path.parents[1]/"launch.json"
    return {"schema_version":1,"status":"verified_original_clip_polling" if effective else "incomplete_or_inconclusive",
            "controlled_trace_complete":complete,"source_fps":25,"log_snapshot":source["log_snapshot"],
            "observer":source["observer"],"provenance":source["provenance"],
            "launch":json.loads(launch_path.read_text(encoding="utf-8-sig")),
            "missing_ticks":missing,"duplicates":source["duplicate_records"],"install":source["installs"],"done":source["done"],
            "restoration_verified":restored,"method_and_this_verified_all_samples":method_all,
            "non_probe_call_records":len(source["calls"]),"true_non_probe_call_records":len(original_calls),
            "ground_cases":ground,"jump_cases":jumps,"source_counter_confirmed_shots":shot_total,
            "raw_fixture_shot_total":source["done"][0].get("shot_total") if source["done"] else None,
            "fixture_shot_counter_limitation":"MovieClip references for reused names compare equal even when the clip is replaced. new_shots/shot_total undercount later jumps. Use original sub_i increments AND projectile frame1 records; preserve raw counter instead of rewriting it.",
            "sampling":"Fixture snapshot precedes the remaining original callbacks. CALL t124 already sees parent child16 whereas snapshot t124 sees15. Assign source events using callback child/sub plus following snapshot, never a blanket observer-tick offset.",
            "godot_comparison":{"kind":"static implementation review only; no same-condition Godot trajectory run by this analyzer",
                "air_cycle":"Current _advance_air_action matches sampled default15:1,16:2,17:3 fire,18:4,19:5,20:6->2 and repeated21/25/29 fire. No permanent stopped2 observed.",
                "potential_first_difference":"Source return tick with held direction immediately enters parent2 and moves6 (t199/t254). Current Battle.step polls _player_input before player.advance_tick; unless a later return callback polls direction, landing movement will be one source tick late. Requires same-condition Godot regression; not labeled measured Godot failure."},
            "limitations":["Controlled native Key object method, not natural keyboard events or native Adobe Flash.",
                           "Direct goto95 bypasses C entry gates; no real keyDown dispatched; ground X trigger is not validated.",
                           "Default equipment, crt0, nan0, root2 only; no general shot-period rule for equipment variants.",
                           "Enemy x900 reset is an intervention and original common boundary may clamp it; contact outcomes are not asserted here.",
                           "Projectile frame11 empty clips persist across trials; replaced names must not be counted only by object-reference inequality."],
            "warnings":source["warnings"],"timeline":list(rows.values()),"calls":source["calls"]}


def analyze(basic_path: Path, native_path: Path, held_path: Path = DEFAULT_HELD) -> dict:
    basic = read_snapshot(basic_path, "LEBA_M1")
    native = read_snapshot(native_path, "LEBA_M1_NATIVE")
    cases = [summarize_case(basic, *entry) for entry in SCHEDULE]
    failed_input_rows = [basic["rows"][t] for t in range(50, 66) if t in basic["rows"]]
    jumps = [c for c in cases if c["case"].startswith("c_")]
    positions = sorted({r["px"] for r in failed_input_rows})
    missing_fixture = [t for t in range(30,390) if not {"LEBA_M1","LEIBA02","LEIBA02_DETAIL"}.issubset(basic["records"].get(t,{}))]
    ground_parents = sorted({r["parent"] for r in failed_input_rows})
    shot_count = sum(len(c["shot_records"]) for c in jumps)
    override_not_effective = (not missing_fixture and len(positions)==1 and ground_parents==[1]
                              and shot_count==0 and all(c["observed_air_subframes"]==[1] for c in jumps))
    complete = bool(basic["done"]) and not basic["duplicate_records"] and basic["observer"]["matches_provenance"]
    complete = complete and not missing_fixture and all(not case["missing_record_ticks"] for case in cases)
    z_native = native_z_cases(native)
    coverage = [{"action": c["case"], "kind": "controlled parent goto, original child execution",
                 "sample_range": [c["fixture_start_tick"], c["first_return_idle_tick"]],
                 "active_child_samples": c["observed_child_sequence_before_return"],
                 "root_delta": c["root_dx_entry_to_return"],
                 "input_validated": False} for c in cases]
    for c in z_native:
        coverage.append({"action": "host_key_Z", "kind": "host key event with earlier input contamination",
                         "sample_range": [c["event"]["previous_observer_tick"], c["first_return_idle_tick"]],
                         "root_delta": c["root_dx_before_event_to_return"],
                         "net_mp_delta_first_sample": c["observed_mp_delta_at_first_sample"],
                         "input_validated": "host code90 observed; not an isolated controlled keyboard session"})
    metadata = lambda s: {k:s[k] for k in ("log_snapshot","provenance","observer","warnings","duplicate_records")}
    return {"schema_version":1, "controlled_trace_complete":complete,
            "sampling":"Fixture runs before LEIBA02/base/detail observer records; terminal control frames may execute and vanish in the same source tick. A sample is not a full display interval.",
            "source_fps":25, "basic_source":metadata(basic), "native_source":metadata(native),
            "missing_fixture_sample_ticks":missing_fixture,
            "done_markers":basic["done"], "coverage":coverage, "controlled_cases":cases,
            "attempted_input_override":{
                "status":"not_effective_in_observed_behavior; movement and held-X NOT validated" if override_not_effective else "incomplete_or_changed_observations; inspect_trace_before_any_input_validation",
                "declared_mock_interventions":"observer.as assigns Key.isDown and held[39/37/88]; log never confirms the effective function value",
                "ground_window":[50,65], "observed_root_positions":positions,
                "observed_ground_parents":ground_parents,
                "jump_air_subframes":{c["case"]:c["observed_air_subframes"] for c in jumps},
                "shot_record_count_in_controlled_windows":shot_count,
                "conclusion":"No observed ground displacement, no air child2..6 and no shot records in attempted held windows. This contradicts using the fixture as validation of those inputs; exact override failure mechanism is unproven." if override_not_effective else "This snapshot does not establish the former no-movement/no-shot observation. No keyboard equivalence is inferred automatically.",
                "timeline":failed_input_rows},
            "native_host_keys":native["keys"], "native_z_cases":z_native,
            "held_shadow_experiment":analyze_shadow(held_path),
            "limitations":[
                "Ruffle only; no native Adobe Flash verification or Godot regression is performed by this analyzer.",
                "Basics parent goto bypasses actual C/Down/Z input gates, MP costs and cooldown activation.",
                "Controlled Z cases can interact with the existing enemy/timer state; flyInt values are raw observations, not proof that timers stopped.",
                "Empty-body getBounds returns equal large sentinel values here; retain these raw values and do not treat them as a real world collision rectangle or a direct hitTest result.",
                "Z parent5 last observed child_x=9.95 and root increment=9.9 are separate observed values. No synthetic extra -0.05 rule is inferred; setter quantization needs its own implementation/source reasoning.",
                "Host log contains code65(A),87(W),39(right),90(Z); key-up and full held state were not recorded, so input competition and natural C/airX remain unverified.",
                "The native trace name means host input, not Adobe Flash; startup still uses the fixture shortcut.",
            ]}


def main() -> None:
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--basic-log",type=Path,default=DEFAULT_BASIC)
    parser.add_argument("--native-log",type=Path,default=DEFAULT_NATIVE)
    parser.add_argument("--held-log",type=Path,default=DEFAULT_HELD)
    parser.add_argument("--held-native-log",type=Path,help="Analyze the READ_ONLY-clearing fixture alone, preserving all previous failed-run reports")
    parser.add_argument("--output",type=Path)
    args=parser.parse_args()
    output=(args.output or (DEFAULT_NATIVE_HELD_OUTPUT if args.held_native_log else DEFAULT_OUTPUT)).resolve()
    if not output.is_relative_to((PROJECT/"artifacts").resolve()):
        parser.error("Derived report must remain inside Godot artifacts; source logs are read-only.")
    report=analyze_native_held(args.held_native_log) if args.held_native_log else analyze(args.basic_log,args.native_log,args.held_log)
    output.parent.mkdir(parents=True,exist_ok=True)
    output.write_text(json.dumps(report,ensure_ascii=False,indent=2,allow_nan=False)+"\n",encoding="utf-8")
    if args.held_native_log:
        print(json.dumps({"controlled_trace_complete":report["controlled_trace_complete"],"status":report["status"],
                          "restoration_verified":report["restoration_verified"],"shots":report["source_counter_confirmed_shots"],"output":str(output)},ensure_ascii=False))
    else:print(json.dumps({"controlled_trace_complete":report["controlled_trace_complete"],"coverage":report["coverage"],
                      "native_host_keys":report["native_host_keys"],"held_shadow_status":report["held_shadow_experiment"]["status"],"output":str(output)},ensure_ascii=False))
    if not report["controlled_trace_complete"] or (args.held_native_log and report["status"]!="verified_original_clip_polling"):
        raise SystemExit("Incomplete trace, provenance mismatch, unverified original polling or failed restoration; see derived report.")


if __name__=="__main__":
    main()
