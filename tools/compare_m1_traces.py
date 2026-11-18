"""Compare captured Godot traces to independent controlled original samples.

This reads reports only. It never mutates gameplay, launches a host, or derives an
original expectation from Godot. See each source report for its interventions.
"""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path

PROJECT = Path(__file__).resolve().parents[1]


def read(path):
    raw = path.read_bytes()
    return json.loads(raw), {"path": str(path), "sha256": hashlib.sha256(raw).hexdigest()}


def compare(name, original, actual, *, motion_relative=False, body=True, shots=None):
    first = None
    fields_checked = 0
    if len(original) != len(actual):
        first = {"field": "sample_count", "source": len(original), "godot": len(actual)}
    pairs = [("parent", "parent"), ("px", "x"), ("py", "y")]
    if body:
        pairs += [("body", "body"), ("observed_body_width", "body_width")]
    for index, (src, dst) in enumerate(zip(original, actual)):
        dynamic_pairs = pairs.copy()
        if src.get("parent") in (5, 95):
            dynamic_pairs += [("child", "child"), ("cx", "cx")] if src.get("parent") == 5 else [("child", "child"), ("sub", "air")]
        elif src.get("parent") in (6, 12):
            dynamic_pairs += [("child" if src.get("parent") == 6 else "move", "child")]
        for source_key, godot_key in dynamic_pairs:
            expected = src.get(source_key)
            if not isinstance(expected, (int, float)):
                continue
            value = dst.get(godot_key)
            if source_key == "px" and motion_relative:
                expected -= original[0]["px"]
                value -= actual[0]["x"]
            tolerance = 0.05 if source_key == "observed_body_width" else 0.0001
            fields_checked += 1
            if not isinstance(value, (int, float)) or abs(value-expected) > tolerance:
                if first is None:
                    first = {"sample": index+1, "source_tick": src.get("t"), "field": godot_key,
                             "source": expected, "godot": value, "tolerance": tolerance,
                             "source_record_lines": src.get("record_lines")}
        if src.get("parent") == 95:
            fields_checked += 1
            # Original4..14 is stop1 sprite5627 baked into the base atlas.
            # Overlay represents named5628 at15..29 and its new unnamed stop1
            # replacement at30; undefined named.sub at30 does NOT mean no image.
            expected_visible = isinstance(src.get("child"), (int, float)) and 15 <= src["child"] <= 30
            if dst.get("overlay_visible") != expected_visible and first is None:
                first = {"sample": index+1, "field": "overlay_visible", "source": expected_visible, "godot": dst.get("overlay_visible")}
    if shots is not None:
        source_shots, godot_shots = shots
        expected = [(r["parent_source_frame"], r["air_source_frame"], r["projectiles_at_frame1"][0]["y"]) for r in source_shots]
        observed = [(r["source_frame"], r["sub_frame"], r["parent_y"]) for r in godot_shots]
        fields_checked += len(expected)*3
        match = len(expected) == len(observed) and all(a[:2] == b[:2] and abs(a[2]-b[2]) <= .0001 for a, b in zip(expected, observed))
        if not match and first is None:
            first = {"field": "projectile_creations", "source": expected, "godot": observed}
    return {"case": name, "samples": len(actual), "field_comparisons": fields_checked,
            "position_mode": "relative_to_entry" if motion_relative else "absolute_same_source_fixture",
            "first_difference": first, "passed": first is None}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, default=PROJECT/"artifacts/leba_act01_20261114/regression/m1_actions_tests.json")
    parser.add_argument("--output", type=Path, default=PROJECT/"artifacts/leba_act01_20261114/regression/source_comparison.json")
    args = parser.parse_args()
    basic, basic_prov = read(PROJECT/"artifacts/leba_act01_20261113/controlled_basics.json")
    held, held_prov = read(PROJECT/"artifacts/leba_act01_20261114/held_native.json")
    game, game_prov = read(args.godot)
    source_cases = {c["case"]: c for c in basic["controlled_cases"]}
    traces = game["traces"]
    cases = []
    for trace in traces:
        kind = trace["kind"]
        source_name = None
        relative = False
        if kind == "controlled_source_C_plus_actual_Godot_input":source_name = "c_no_input"
        elif kind == "controlled_source_Down_plus_actual_Godot_input":source_name = "down_facing_right" if trace["facing"] == 1 else "down_facing_left"
        elif kind == "controlled_source_Z5_plus_actual_Godot_input":source_name = "z_parent5"
        elif kind == "controlled_source_Z6_relative_motion":source_name, relative = "z_parent6", True
        if source_name:
            source = source_cases[source_name]
            end = source["first_return_idle_tick"]
            rows = [r for r in source["timeline"] if r["t"] <= end]
            cases.append(compare(source_name+"/"+str(trace.get("mode", trace.get("gate", ""))), rows, trace["samples"], motion_relative=relative))
        if kind == "original_controlled_held_native_comparison":
            source_name = {"face1/reversefalse":"jump_x", "face1/reversetrue":"jump_x_reverse_left", "face-1/reversetrue":"jump_x_reverse_right"}[trace["name"]]
            source = next(c for c in held["jump_cases"] if c["case"] == source_name)
            rows = [r for r in source["timeline"] if r["t"] <= source["return_sample"]["t"]]
            cases.append(compare(source_name, rows, trace["samples"], shots=(source["spawn_samples"], trace["shots"])))
    complete = basic["controlled_trace_complete"] and held["controlled_trace_complete"] and held["restoration_verified"] and len(cases) == 10
    report = {"scope":"Controlled original goto trajectories and verified original-clip held polling compared to captured Godot data. No natural keyboard or Adobe Flash equivalence claim.",
              "sources":[basic_prov, held_prov], "godot_report":game_prov, "source_records_complete":complete,
              "cases":cases, "differences":sum(not c["passed"] for c in cases),
              "first_difference":next((c for c in cases if not c["passed"]), None),
              "tolerance":"Root/child coordinates1e-4px covers float32 representation only; original quantized body bbox width allows0.05px. No frame/tick tolerance.",
              "excluded":"Z milliseconds compare separate timer rules/delta suite; multi-enemy and interruption tests explicitly remain labelled fixtures."}
    output = args.output.resolve()
    if not output.is_relative_to((PROJECT/"artifacts").resolve()):parser.error("Output must stay in artifacts; source reports are read-only.")
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, ensure_ascii=False, indent=2)+"\n",encoding="utf-8")
    print(json.dumps({"cases":len(cases),"complete":complete,"differences":report["differences"],"first_difference":report["first_difference"]},ensure_ascii=True))
    return 0 if complete and report["differences"] == 0 else 1


if __name__ == "__main__":raise SystemExit(main())
