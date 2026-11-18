"""Read persistent-effect original SWF traces without synthesizing missing behavior."""
from __future__ import annotations

import argparse
from collections import Counter, defaultdict
import hashlib
import json
import math
from pathlib import Path


def scalar(value):
    if value in ("undefined", "NaN", "Infinity", "-Infinity"):
        return value
    if value in ("true", "false"):
        return value == "true"
    try:
        n = float(value)
        return int(n) if math.isfinite(n) and n.is_integer() else n if math.isfinite(n) else value
    except ValueError:
        return value


def number(value):
    return isinstance(value, (int, float)) and not isinstance(value, bool)


def short(row, fields):
    return {key: row.get(key) for key in ("t", "ms", "raw_line", *fields)}


def read(log):
    raw = log.read_bytes()
    records, stop_lines, base_ticks = [], [], []
    for lineno, line in enumerate(raw.decode("utf-8-sig").splitlines(), 1):
        if "LEIBA_FIXTURE_DONE" in line:
            stop_lines.append(lineno)
        if "LEIBA02|" in line:
            fields = dict(x.split("=", 1) for x in line.split("LEIBA02|", 1)[1].split("|") if "=" in x)
            base_ticks.append({"t": scalar(fields["t"]), "raw_line": lineno})
        if "ACT02_PERSIST_" not in line:
            continue
        marker, *parts = line.split("ACT02_PERSIST_", 1)[1].split("|")
        row = {key: value if key.endswith("_type") else scalar(value)
               for key, value in (part.split("=", 1) for part in parts if "=" in part)}
        row.update(record_type=marker, raw_line=lineno, order=len(records))
        records.append(row)
    return raw, records, stop_lines, base_ticks


def changes(rows, fields):
    result, prior = [], None
    for row in rows:
        state = tuple(row.get(field) for field in fields)
        if state != prior:
            result.append(short(row, fields))
            prior = state
    return result


def hp_changes(rows):
    result = []
    for a, b in zip(rows, rows[1:]):
        if number(a.get("ehp")) and number(b.get("ehp")) and a["ehp"] != b["ehp"]:
            result.append({"from_tick": a["t"], "to_tick": b["t"], "before": a["ehp"],
                           "after": b["ehp"], "delta": b["ehp"] - a["ehp"], "raw_line": b["raw_line"]})
    return result


def timer_report(states, prefix, flag):
    frames = [r for r in states if number(r.get(prefix + "_timer"))]
    active = [r for r in frames if r.get(flag) == 1]
    first_active = active[0] if active else None
    ended = next((r for r in frames if first_active and r["t"] > first_active["t"] and r.get(flag) == 0), None)
    notable = [r for r in frames if r[prefix + "_timer"] in (1, 2, 8, 9, 354, 355)]
    return {"first_active": short(first_active, (flag, prefix + "_timer")) if first_active else None,
            "first_inactive_after_active": short(ended, (flag, prefix + "_timer")) if ended else None,
            "observed_active_tick_span": ended["t"] - first_active["t"] if ended and first_active else None,
            "flag_transitions": changes(frames, (flag,)),
            "boundary_frames": changes(notable, (flag, prefix + "_timer", "actor", "action"))}


def analyze(log):
    raw, records, stop_lines, base_ticks = read(log)
    states = [r for r in records if r["record_type"] == "STATE" and r.get("tag") == "tick"]
    checks = [r for r in records if r["record_type"] == "CHECK"]
    finishes = [r for r in records if r["record_type"] == "DONE"]
    finish = finishes[-1] if finishes else None
    errors = []
    if len(finishes) != 1:
        errors.append(f"Expected one DONE record, got {len(finishes)}")
    if not stop_lines:
        errors.append("LEIBA_FIXTURE_DONE missing")
    for row in checks:
        if row.get("ok") is not True:
            errors.append(f"Fixture check failed: {row.get('name')} at tick {row.get('t')}, line {row['raw_line']}")
    if finish and finish.get("Key_unchanged") is not True:
        errors.append("Original Key function or object identity changed")
    launch_file = log.parent.parent / "launch.json"
    launch = json.loads(launch_file.read_text(encoding="utf-8-sig")) if launch_file.exists() else None
    if launch and launch.get("original_sha256_before") != launch.get("original_sha256_after"):
        errors.append("Original file after-hash absent or changed")
    floor_states = [r for r in states if number(r.get("r1503"))]
    floor_wraps = []
    for before, after in zip(floor_states, floor_states[1:]):
        if after["r1503"] < before["r1503"]:
            fields = ("floor", "r1503", "r1503_serial", "r1502", "r1502_serial")
            floor_wraps.append({"before": short(before, fields), "after": short(after, fields)})
    c4_states = [r for r in states if r.get("case") == "C4_attach_detonate"]
    c4_rows = [r for r in records if r["record_type"] == "C4" and r.get("tag") == "tick"]
    c4_groups = defaultdict(list)
    for row in c4_rows:
        c4_groups[row["name"]].append(row)
    fire_rows = [r for r in records if r["record_type"] == "FIRE" and r.get("tag") == "tick"]
    attempts = defaultdict(list)
    for row in fire_rows:
        attempts[row["attempt"]].append(row)
    fire_results = []
    for attempt, rows in sorted(attempts.items()):
        samples = [r for r in states if rows[0]["t"] <= r["t"] <= rows[-1]["t"]]
        fire_results.append({"attempt": attempt, "first_tick": rows[0]["t"], "last_tick": rows[-1]["t"],
                             "branches_seen": sorted({str(r.get("branch")) for r in rows}),
                             "transitions": changes(rows, ("frame", "branch", "hit", "normal", "air")),
                             "hp_changes": hp_changes(samples),
                             "enemy_samples": changes(samples, ("ehp", "outer", "enemy", "marker", "g", "gacc"))})
    bullets = [r for r in records if r["record_type"] == "Y_BULLET" and r.get("tag") == "tick"]
    bullet_groups = defaultdict(list)
    for row in bullets:
        bullet_groups[(str(row.get("owner")), str(row.get("key")))].append(row)
    bullet_summary = [{"owner": owner, "key": key, "samples": len(rows), "first": rows[0], "last": rows[-1],
                       "root_lookup_same_values": sorted({str(r.get("root_lookup_same")) for r in rows})}
                      for (owner, key), rows in bullet_groups.items()]
    return {
        "schema": "leba-act02-persistent-observation-v1",
        "evidence_class": "Controlled original clips in Ruffle0.7.1 derived SWF; not native input or Adobe Flash",
        "log": str(log.resolve()), "sha256": hashlib.sha256(raw).hexdigest(), "launch": launch,
        "integrity": {"ok": not errors, "errors": errors,
                      "record_counts": dict(Counter(r["record_type"] for r in records)),
                      "literal_special_value_counts": dict(Counter(str(v) for r in records for v in r.values()
                                                                   if v in ("undefined", "NaN", "Infinity", "-Infinity"))),
                      "runner_done_lines": stop_lines, "last_source_tick": base_ticks[-1]["t"] if base_ticks else None,
                      "extra_source_ticks_after_DONE": max(0, base_ticks[-1]["t"] - finish["t"]) if base_ticks and finish else None},
        "limits": ["All entries/choice seeks and position/HP2000/gravity resets are declared fixture interventions.",
                   "Timer clocks, source scripts, Key and Math.random were not replaced or fast-forwarded.",
                   "731 is instantiated directly; its projectile-origin entry and costs are not tested.",
                   "Branch coverage is observed, never forced. Missing branches/checks remain failures.",
                   "State is observed before remaining queued callbacks, not every operation inside each tick.",
                   "Y covers one normal entry and recorded hosts, not full movement/focus/expiration behavior.",
                   "Enemy HP deltas include all original observers, not just one effect coefficient.",
                   "Undefined/NaN values remain literal strings; no guessed default is substituted."],
        "checks": checks, "finish": finish,
        "q_fire_timer": timer_report(states, "fire", "zak"),
        "q_silver_timer": timer_report(states, "silver", "eun"),
        "r_floor": {"first": floor_states[0] if floor_states else None, "last": floor_states[-1] if floor_states else None,
                    "source30_wraps": floor_wraps, "source1503_serials": sorted({r["r1503_serial"] for r in floor_states}),
                    "source1502_serials": sorted({r["r1502_serial"] for r in floor_states}),
                    "samples": [short(r, ("floor", "r1503", "r1503_serial", "r1502", "r1502_serial")) for r in floor_states]},
        "c4": {"hp_changes": hp_changes(c4_states),
               "actor_container_transitions": changes(c4_states, ("actor", "action", "c4", "c4container", "c4_attach_helper")),
               "bomb_transitions": {name: changes(rows, ("frame", "flash", "hit", "normal", "air")) for name, rows in c4_groups.items()}},
        "fire731_attempts": fire_results,
        "y": {"root_transitions": changes([r for r in states if r["t"] >= 685], ("actor", "action", "yroot", "ynormal", "yx", "yy", "bk")),
              "bullet_hosts": bullet_summary},
        "records": records,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--log", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    result = analyze(args.log)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2, allow_nan=False) + "\n", encoding="utf-8")
    print(json.dumps({"output": str(args.output.resolve()), "integrity": result["integrity"],
                      "finish": result["finish"], "c4_hp_changes": result["c4"]["hp_changes"]}, ensure_ascii=False))
    raise SystemExit(0 if result["integrity"]["ok"] else 1)


if __name__ == "__main__":
    main()
