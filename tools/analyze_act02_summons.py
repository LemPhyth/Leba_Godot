"""Read ACT02 A/W source observations, preserving failed fixtures and unknowns.

No gameplay values are filled in or simulated. --log and --output are required.
"""
from __future__ import annotations

import argparse
from collections import Counter, defaultdict
import hashlib
import json
import math
from pathlib import Path


PREFIX = "ACT02_SUMMONS_"
STATE_FIELDS = ("t", "ms", "tag", "ehp", "ex", "ey", "outer", "enemy",
                "body", "air", "marker", "g", "gacc", "pin_enemy", "raw_line")
OBJECT_FIELDS = ("t", "ms", "key", "kind", "asdepth", "frame", "wait", "x", "y",
                 "sx", "mobsp", "mobsp_type", "wait_normal", "blast", "blast_normal",
                 "blast_air", "raw_line")


def scalar(raw):
    if raw in ("undefined", "NaN", "Infinity", "-Infinity"):
        return raw
    if raw in ("true", "false"):
        return raw == "true"
    try:
        number = float(raw)
        if not math.isfinite(number):
            return raw
        return int(number) if number.is_integer() else number
    except ValueError:
        return raw


def numeric(value):
    return isinstance(value, (int, float)) and not isinstance(value, bool)


def compact(row, fields):
    return {key: row.get(key) for key in fields}


def parse(log):
    data = log.read_bytes()
    records, base_ticks, stop_lines = [], [], []
    for line_number, line in enumerate(data.decode("utf-8-sig").splitlines(), 1):
        if "LEIBA_FIXTURE_DONE" in line:
            stop_lines.append(line_number)
        if "LEIBA02|" in line:
            fields = dict(item.split("=", 1) for item in line.split("LEIBA02|", 1)[1].split("|") if "=" in item)
            base_ticks.append({"t": scalar(fields["t"]), "raw_line": line_number})
        if PREFIX not in line:
            continue
        payload = line.split(PREFIX, 1)[1]
        record_type, *parts = payload.split("|")
        row = {}
        for part in parts:
            if "=" in part:
                key, value = part.split("=", 1)
                row[key] = value if key.endswith("_type") else scalar(value)
        row.update(record_type=record_type, raw_line=line_number, order=len(records))
        records.append(row)
    return data, records, base_ticks, stop_lines


def case_summary(case, records):
    states = [r for r in records if r["record_type"] == "STATE" and r.get("case") == case and r.get("tag") == "tick"]
    objects = [r for r in records if r["record_type"] == "OBJECT" and r.get("case") == case and r.get("tag") == "tick"]
    hp_changes = []
    for before, after in zip(states, states[1:]):
        if numeric(before.get("ehp")) and numeric(after.get("ehp")) and before["ehp"] != after["ehp"]:
            hp_changes.append({"from_tick": before["t"], "to_tick": after["t"],
                               "before": before["ehp"], "after": after["ehp"],
                               "delta": after["ehp"] - before["ehp"], "raw_line": after["raw_line"]})
    groups = defaultdict(list)
    for row in objects:
        groups[str(row.get("key"))].append(row)
    tracks = []
    for key, rows in groups.items():
        transitions, deltas = [], []
        prior = None
        for row in rows:
            if prior is None or row.get("frame") != prior.get("frame"):
                transitions.append(compact(row, OBJECT_FIELDS))
            if prior is not None and row["t"] == prior["t"] + 1 and numeric(row.get("x")) and numeric(prior.get("x")):
                deltas.append({"t": row["t"], "from_frame": prior.get("frame"), "to_frame": row.get("frame"),
                               "from_wait": prior.get("wait"), "to_wait": row.get("wait"),
                               "dx": round(row["x"] - prior["x"], 10), "raw_line": row["raw_line"]})
            prior = row
        counts = Counter(str(r.get("mobsp_type")) for r in rows)
        wait_deltas = Counter(str(r["dx"]) for r in deltas if r["from_frame"] == r["to_frame"] == 1)
        tracks.append({"key": key, "first": compact(rows[0], OBJECT_FIELDS), "last": compact(rows[-1], OBJECT_FIELDS),
                       "source_frame_transitions": transitions, "mobsp_type_samples": dict(counts),
                       "parent1_adjacent_tick_dx_counts": dict(wait_deltas), "x_deltas": deltas,
                       "wait_terminal_samples": [compact(r, OBJECT_FIELDS) for r in rows
                                                 if numeric(r.get("wait")) and r["wait"] >= 146]})
    interesting_ticks = set()
    for change in hp_changes:
        interesting_ticks.update(range(change["to_tick"] - 2, change["to_tick"] + 3))
    return {"case": case, "first_state": compact(states[0], STATE_FIELDS) if states else None,
            "last_state": compact(states[-1], STATE_FIELDS) if states else None,
            "hp_changes": hp_changes,
            "observed_hp_change_sum": sum(row["delta"] for row in hp_changes),
            "tracks": tracks,
            "damage_window_states": [compact(r, STATE_FIELDS) for r in states if r["t"] in interesting_ticks],
            "damage_window_objects": [compact(r, OBJECT_FIELDS) for r in objects if r["t"] in interesting_ticks]}


def analyze(log):
    data, records, base_ticks, stop_lines = parse(log)
    checks = [r for r in records if r["record_type"] == "CHECK"]
    finishes = [r for r in records if r["record_type"] == "DONE"]
    finish = finishes[-1] if finishes else None
    errors = []
    if not records:
        errors.append("No ACT02_SUMMONS records")
    if len(finishes) != 1:
        errors.append(f"Expected exactly one DONE record, got {len(finishes)}")
    if not stop_lines:
        errors.append("LEIBA_FIXTURE_DONE missing")
    if finish and finish.get("reason") != "scheduled_complete":
        errors.append("Fixture did not reach scheduled_complete")
    failures = [r for r in checks if r.get("ok") is not True]
    for row in failures:
        errors.append(f"Fixture check failed: {row.get('name')} at source tick {row.get('t')}, log line {row['raw_line']}")
    if finish and finish.get("Key_unchanged") is not True:
        errors.append("Original Key object/function identity changed")
    launch_path = log.parent.parent / "launch.json"
    launch = json.loads(launch_path.read_text(encoding="utf-8-sig")) if launch_path.exists() else None
    if launch and launch.get("original_sha256_before") != launch.get("original_sha256_after"):
        errors.append("Original source hash is different or after hash missing")
    counts = Counter(r["record_type"] for r in records)
    special_values = Counter(str(v) for r in records for v in r.values() if v in ("undefined", "NaN", "Infinity", "-Infinity"))
    return {
        "schema": "leba-act02-summons-observation-v1",
        "evidence_class": "Ruffle 0.7.1 controlled derived-SWF fixture, not native keyboard or Adobe Flash",
        "log": str(log.resolve()), "log_sha256": hashlib.sha256(data).hexdigest(), "launch": launch,
        "integrity": {"ok": not errors, "errors": errors, "record_counts": dict(counts),
                      "literal_special_value_counts": dict(special_values), "runner_done_lines": stop_lines,
                      "last_source_tick": base_ticks[-1]["t"] if base_ticks else None,
                      "extra_source_ticks_after_DONE": max(0, base_ticks[-1]["t"] - finish["t"]) if base_ticks and finish else None},
        "limits": [
            "Parent113 seeks with a flag bypass original input, MP and cooldown gates.",
            "Enemy hp/hpm=2000 replaces training1e22 only for small-delta precision.",
            "Actor/enemy positions, ground/gravity and facing are seeded between cases.",
            "Timeout case pins enemy550, then relocates it at original wait148; this is not natural AI play.",
            "Only source observer-stage samples are recorded, not every operation inside a host tick.",
            "No setter is hooked: undefined mobsp plus finite displacement is host-behavior evidence, not direct setter trace.",
            "All undefined/NaN/Infinity values and failed preconditions remain in this report.",
            "Observed HP deltas include all original active observers; do not label one script's coefficient the total.",
            "Wall-clock milliseconds are host observations and are not assumed to equal source ticks times40ms.",
        ],
        "profiles": [r for r in records if r["record_type"] == "PROFILE"],
        "checks": checks, "finish": finish,
        "cases": [case_summary(case, records) for case in ("A_contact", "A_timeout", "W_contact")],
        "records": records,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--log", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    report = analyze(args.log)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2, allow_nan=False) + "\n", encoding="utf-8")
    print(json.dumps({"output": str(args.output.resolve()), "integrity": report["integrity"],
                      "hp_changes": {case["case"]: case["hp_changes"] for case in report["cases"]}}, ensure_ascii=False))
    raise SystemExit(0 if report["integrity"]["ok"] else 1)


if __name__ == "__main__":
    main()
