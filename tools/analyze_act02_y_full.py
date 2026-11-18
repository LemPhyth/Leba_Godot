"""Read original Y full-lifetime probe; retain failures and unobserved coverage."""
from __future__ import annotations

import argparse
from collections import Counter, defaultdict
import hashlib
import json
from pathlib import Path

from analyze_act02_persistent import scalar, number, changes, hp_changes


def read(log: Path):
    raw = log.read_bytes()
    records, done_lines, base_ticks = [], [], []
    for line_no, line in enumerate(raw.decode("utf-8-sig").splitlines(), 1):
        if "LEIBA_FIXTURE_DONE" in line:
            done_lines.append(line_no)
        if "LEIBA02|" in line:
            fields = dict(part.split("=", 1) for part in line.split("LEIBA02|", 1)[1].split("|") if "=" in part)
            base_ticks.append(scalar(fields["t"]))
        if "ACT02_Y_" not in line:
            continue
        kind, *parts = line.split("ACT02_Y_", 1)[1].split("|")
        row = {key: scalar(value) for key, value in (part.split("=", 1) for part in parts if "=" in part)}
        row.update(record_type=kind, raw_line=line_no, order=len(records))
        records.append(row)
    return raw, records, done_lines, base_ticks


def brief(row, fields):
    return {key: row.get(key) for key in ("t", "raw_line", *fields)}


def coverage(rows):
    helpers = [r for r in rows if r["record_type"] == "HELPER"]
    bullets = [r for r in rows if r["record_type"] == "BULLET"]
    states = [r for r in rows if r["record_type"] == "STATE"]
    contacts = [r for r in helpers if r.get("normal") is True or r.get("air") is True]
    bullet_contacts = [r for r in bullets if r.get("normal") is True or r.get("air") is True]
    bullet_hits = [r for r in bullets if r.get("hita") == 1]
    # Phase filters can join distinct phase1 spans before/after a summon. Never
    # attribute HP lost during an omitted phase to that artificial adjacency.
    deltas = [d for d in hp_changes(states) if d["to_tick"] == d["from_tick"]+1]
    losses = [r for r in deltas if r["delta"] < 0]
    return {
        "1140_contact": bool(contacts), "bullet_contact": bool(bullet_contacts),
        "bullet_hita1": bool(bullet_hits), "enemy_HP_decreased": bool(losses),
        "first_1140_contact": contacts[0] if contacts else None,
        "first_bullet_contact": bullet_contacts[0] if bullet_contacts else None,
        "first_bullet_hita1": bullet_hits[0] if bullet_hits else None,
        "observed_contacting_1140_units": sorted({r["unit_id"] for r in contacts}),
        "bullet_hit_instance_serials": sorted({r["serial"] for r in bullet_hits}),
        "hp_changes": deltas,
        "unobserved": [label for label, seen in (("1140 actual contact", contacts), ("bullet actual contact", bullet_contacts),
                                                  ("bullet original hita1", bullet_hits), ("enemy HP decrease", losses)) if not seen],
        "attribution_limit": "Contacts/hita and HP are observed. Shared marker observers can overlap; these are not isolated per-object damage coefficients.",
    }


def analyze(log: Path):
    raw, records, done_lines, base_ticks = read(log)
    states = [r for r in records if r["record_type"] == "STATE"]
    checks = [r for r in records if r["record_type"] == "CHECK"]
    finishes = [r for r in records if r["record_type"] == "DONE"]
    finish = finishes[-1] if finishes else None
    errors = []
    if len(finishes) != 1:
        errors.append(f"Expected one DONE, observed {len(finishes)}")
    if not done_lines:
        errors.append("LEIBA_FIXTURE_DONE missing")
    for row in checks:
        if row.get("ok") is not True:
            errors.append(f"Declared check failed: {row.get('name')}, t={row.get('t')}, raw line {row['raw_line']}")
    if finish and finish.get("failures") != 0:
        errors.append(f"Fixture reports {finish.get('failures')} failures")
    expected_ticks = set(range(30, 701))
    observed_ticks = {r.get("t") for r in states}
    missing = sorted(expected_ticks - observed_ticks)
    if missing:
        errors.append(f"Missing {len(missing)} declared STATE ticks")
    launch_path = log.parent.parent / "launch.json"
    launch = json.loads(launch_path.read_text(encoding="utf-8-sig")) if launch_path.exists() else None
    if launch and launch.get("original_sha256_before") != launch.get("original_sha256_after"):
        errors.append("Original after-hash missing or differs")
    expected_unit_counts = {4423: 99, 4433: 46, 4436: 42, 4459: 34, 4461: 13, 4462: 13, 4463: 13,
                            4464: 13, 4482: 6, 4483: 20, 4484: 26, 4485: 5}
    mismatched_objects = []
    for row in records:
        kind = row["record_type"]
        want = expected_unit_counts.get(row.get("source_id")) if kind == "UNIT" else 3 if kind == "HELPER" else 11 if kind == "BULLET" else None
        if want is not None and row.get("total") != want:
            mismatched_objects.append(brief(row, ("record_type", "source_id", "unit_id", "path", "frame", "total")))
    if mismatched_objects:
        errors.append(f"{len(mismatched_objects)} objects fail expected source frame-count identity check; preserve raw labels")
    cases = {}
    for name in ("natural_normal_expiration", "walk_stop_focus_expiration"):
        rows = [r for r in records if r.get("case") == name]
        samples = [r for r in rows if r["record_type"] == "STATE"]
        phase_transitions = changes(samples, ("yroot", "normal", "bk", "actor"))
        phases = defaultdict(list)
        for row in samples:
            phases[str(row.get("yroot"))].append(row)
        units = defaultdict(list)
        for row in rows:
            if row["record_type"] == "UNIT":
                units[(row.get("group"), row.get("source_id"), row.get("serial"))].append(row)
        instance_reports = []
        for (group, source_id, serial), instance in units.items():
            wraps = [{"from_tick": a["t"], "to_tick": b["t"], "from_frame": a["frame"], "to_frame": b["frame"], "raw_line": b["raw_line"]}
                     for a, b in zip(instance, instance[1:]) if number(a.get("frame")) and number(b.get("frame")) and b["frame"] < a["frame"]]
            instance_reports.append({"group": group, "source_id": source_id, "serial": serial,
                                     "first": instance[0], "last": instance[-1], "wraps": wraps})
        boundary_ticks = set()
        for before, after in zip(samples, samples[1:]):
            if before.get("yroot") != after.get("yroot"):
                boundary_ticks.update(range(int(after["t"])-2, int(after["t"])+3))
        cases[name] = {
            "first": samples[0] if samples else None, "last": samples[-1] if samples else None,
            "phase_transitions": phase_transitions,
            "phase_spans": {phase: {"first_tick": seq[0]["t"], "last_tick": seq[-1]["t"], "samples": len(seq),
                                     "contains_gaps": any(b["t"] != a["t"]+1 for a, b in zip(seq, seq[1:]))} for phase, seq in phases.items()},
            "timer_boundaries": [brief(r, ("actor", "yroot", "timer", "focus_timer", "exit", "slot", "slot_serial", "bk"))
                                 for r in samples if r["t"] in boundary_ticks or r.get("timer") in (1, 160, 161, 186, 187, 211, 212, 236, 237, 261, 262, 291, 292)
                                 or r.get("focus_timer") in (1, 79, 80, 81)],
            "unit_instances": instance_reports,
            "coverage": coverage(rows),
            "phase_specific_coverage": {phase: coverage([r for r in rows if r.get("t") in {x["t"] for x in seq}]) for phase, seq in phases.items()},
        }
    bullets = [r for r in records if r["record_type"] == "BULLET"]
    bullet_instances = defaultdict(list)
    for row in bullets:
        bullet_instances[row.get("serial")].append(row)
    hp_correlations = []
    for case in cases.values():
        for delta in case["coverage"]["hp_changes"]:
            t = delta["to_tick"]
            nearby = [brief(r, ("record_type", "unit_id", "unit_frame", "serial", "frame", "helper", "hita", "normal", "air", "path"))
                      for r in records if r["record_type"] in ("HELPER", "BULLET") and t-2 <= r.get("t", -999) <= t]
            hp_correlations.append({**delta, "nearby_observed_original_objects": nearby,
                                    "not_exclusive_attribution": True})
    return {
        "schema": "leba-act02-y-full-observation-v1",
        "evidence_class": "Controlled original default clips in derived SWF/Ruffle0.7.1; not OS keyboard or native Adobe Flash",
        "log": str(log.resolve()), "sha256": hashlib.sha256(raw).hexdigest(), "launch": launch,
        "integrity": {"ok": not errors, "errors": errors, "missing_ticks": missing, "object_identity_mismatches": mismatched_objects,
                      "record_counts": dict(Counter(r["record_type"] for r in records)),
                      "literal_special_value_counts": dict(Counter(str(v) for r in records for v in r.values() if v in ("undefined", "NaN", "Infinity", "-Infinity"))),
                      "runner_done_lines": done_lines, "last_source_tick": base_ticks[-1] if base_ticks else None,
                      "extra_source_ticks_after_DONE": max(0, base_ticks[-1]-finish["t"]) if base_ticks and finish else None},
        "limits": [
            "Declared position/HP2000/gravity baselines and original parent24/25 entries are controlled interventions.",
            "No original script, timer, random, source bullet host, marker or damage result was replaced.",
            "Direct parent entry bypasses input/cost/readiness and original skill-slot stop2. Untouched slot observation is not natural-entry cooldown acceptance.",
            "Second case uses the same scene after natural first exit; original dynamic children are not forcibly removed.",
            "1140 helpers have independent clocks; empty frame3 instances can retain damage observers until their parent removes them.",
            "Bullet hita1 proves original helper bookkeeping; HP can include concurrent shared observers and is not exclusively attributed by temporal proximity.",
            "Undefined/NaN and missing coverage remain explicit, not defaulted or synthesized.",
            "STATE phase is observer_before_remaining_callbacks, not a full instruction-level ordering trace.",
        ],
        "checks": checks, "finish": finish, "cases": cases, "coverage": coverage(records),
        "bullet_hosts": [{"serial": serial, "first": seq[0], "last": seq[-1], "samples": len(seq),
                          "observed_hita1": any(r.get("hita") == 1 for r in seq),
                          "root_lookup_same_values": sorted({str(r.get("root_lookup_same")) for r in seq})}
                         for serial, seq in bullet_instances.items()],
        "HP_correlations_not_exclusive_damage_attribution": hp_correlations, "records": records,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--log", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    result = analyze(args.log)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2, allow_nan=False)+"\n", encoding="utf-8")
    print(json.dumps({"output": str(args.output.resolve()), "integrity": result["integrity"], "finish": result["finish"],
                      "coverage": {key: value for key, value in result["coverage"].items() if key not in ("hp_changes", "first_1140_contact", "first_bullet_contact", "first_bullet_hita1", "bullet_hit_instance_serials")}}, ensure_ascii=False))
    raise SystemExit(0 if result["integrity"]["ok"] else 1)


if __name__ == "__main__":
    main()
