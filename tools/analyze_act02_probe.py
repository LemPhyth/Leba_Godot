"""Read ACT02 training-default traces; never simulate missing source behavior.

Usage: python tools/analyze_act02_probe.py --log PATH --output PATH
Original line numbers and immediate fixture effects are retained separately
from later source callbacks. This validates log integrity, not natural input.
"""
from __future__ import annotations

import argparse
from collections import Counter
import hashlib
import json
import math
from pathlib import Path


PREFIXES = (
    "ACT02_DEFAULTS_SCHEMA", "ACT02_DEFAULTS_PROFILE", "ACT02_DEFAULTS_EVENT",
    "ACT02_DEFAULTS_STATE", "ACT02_DEFAULTS_CHECK", "ACT02_DEFAULTS_DONE",
)
SLOTS = ("za", "s", "d", "q", "t_slot", "e", "r", "y", "v", "w", "f", "g", "h")
RESET_FIELDS = ("root", "actor", "action", "hp", "hpm", "mp", "mpm", "bar",
                "urlaa", *SLOTS, "f_stock", "f_hud", "f_icon", "f_icon_same")


def scalar(raw: str):
    if raw == "undefined":
        return None
    if raw == "true":
        return True
    if raw == "false":
        return False
    try:
        number = float(raw)
        if not math.isfinite(number):
            return raw  # Preserve source NaN/Infinity as text, not invalid JSON.
        return int(number) if number.is_integer() else number
    except ValueError:
        return raw


def read_records(log: Path):
    data = log.read_bytes()
    lines = data.decode("utf-8-sig").splitlines()
    records = []
    source_ticks = []
    done_lines = []
    for line_number, line in enumerate(lines, 1):
        if "LEIBA_FIXTURE_DONE" in line:
            done_lines.append(line_number)
        if "LEIBA02|" in line:
            values = dict(item.split("=", 1) for item in
                          line.split("LEIBA02|", 1)[1].split("|") if "=" in item)
            source_ticks.append({"t": scalar(values["t"]), "raw_line": line_number})
        for prefix in PREFIXES:
            marker = prefix + "|"
            if marker not in line:
                continue
            record = {key: value if key.endswith("_type") else scalar(value) for key, value in
                      (item.split("=", 1) for item in line.split(marker, 1)[1].split("|")
                       if "=" in item)}
            record.update(kind=prefix, raw_line=line_number, order=len(records))
            records.append(record)
            break
    return data, records, source_ticks, done_lines


def select(records, kind):
    return [row for row in records if row["kind"] == kind]


def compact(row, fields=RESET_FIELDS):
    return {key: row.get(key) for key in ("t", "ms", "tag", "raw_line", *fields)}


def first(rows, predicate):
    return next((row for row in rows if predicate(row)), None)


def reset_window(label, states, events):
    event = first(events, lambda row: row.get("event") == label)
    if event is None:
        return {"event": None, "observed": False}
    tick = event["t"]
    before = first(states, lambda row: row.get("tag") == "before_" + label)
    after = first(states, lambda row: row.get("tag") == "after_" + label)
    following = [row for row in states if row.get("tag") == "tick"
                 and tick < row["t"] <= tick + 30]
    stable = first(following, lambda row: row.get("urlaa") == 0
                   and row.get("bar") == 1 and row.get("actor") in (1, 2, 3, 4))
    return {
        "observed": True, "event": event,
        "before": compact(before) if before else None,
        "immediate_fixture_effect": compact(after) if after else None,
        "following_original_samples": [compact(row) for row in following],
        "first_observed_basic_actor_bar1_latch0": compact(stable) if stable else None,
        "ticks_to_first_observed_basic_actor_bar1_latch0": stable["t"] - tick if stable else None,
        "note": "Immediate writes are fixture effects; following samples are original scripts. "
                "This definition does not assert which callback executed first within a tick.",
    }


def analyze(log: Path):
    data, records, source_ticks, done_lines = read_records(log)
    states = select(records, "ACT02_DEFAULTS_STATE")
    events = select(records, "ACT02_DEFAULTS_EVENT")
    checks = select(records, "ACT02_DEFAULTS_CHECK")
    finishes = select(records, "ACT02_DEFAULTS_DONE")
    finish = finishes[-1] if finishes else None
    errors = []
    if not records:
        errors.append("No ACT02 records")
    if len(finishes) != 1:
        errors.append(f"Expected one ACT02_DEFAULTS_DONE, observed {len(finishes)}")
    if not done_lines:
        errors.append("LEIBA_FIXTURE_DONE missing")
    for check in checks:
        if check.get("ok") is not True:
            errors.append(f"Fixture precondition failed: {check.get('name')} at line {check['raw_line']}")
    if finish:
        if finish.get("reason") != "scheduled_complete":
            errors.append(f"Fixture did not reach scheduled completion: {finish.get('reason')}")
        for key in ("original_restored", "read_only_restored", "root_key_unchanged"):
            if finish.get(key) is not True:
                errors.append(f"Restore check failed: {key}")
    ticks_after_done = []
    if done_lines:
        ticks_after_done = [row for row in source_ticks if row["raw_line"] > done_lines[0]]
    y_event = first(events, lambda row: row.get("event") == "original_Y_first_ready533")
    f_states = [row for row in states if 570 <= row["t"] <= 710]
    icon_resumes = [row for row in f_states if row.get("tag") == "tick"
                    and row["t"] > 610 and row.get("f_icon") == 1]
    launch_path = log.parent.parent / "launch.json"
    launch = json.loads(launch_path.read_text(encoding="utf-8-sig")) if launch_path.exists() else None
    profiles = select(records, "ACT02_DEFAULTS_PROFILE")
    unset_profile = [key for key in ("weapon", "armor", "ring", "fly_c4", "sonic", "master", "awakening2", "cubes")
                     if profiles and profiles[0].get(key) is None]
    return {
        "schema": "leba-act02-defaults-observation-v1",
        "evidence_class": "Ruffle 0.7.1 derived SWF, controlled fixture; not native keyboard/Adobe Flash",
        "log": str(log.resolve()), "sha256": hashlib.sha256(data).hexdigest(),
        "launch": launch,
        "integrity": {"ok": not errors, "errors": errors, "record_counts": dict(Counter(r["kind"] for r in records)),
                      "last_source_tick": source_ticks[-1]["t"] if source_ticks else None,
                      "runner_done_lines": done_lines, "source_samples_after_done": ticks_after_done,
                      "additional_source_ticks_after_done": max(0, source_ticks[-1]["t"] - finish["t"])
                      if source_ticks and finish else None},
        "bootstrap_boundary": {"unset_profile_fields_at_t25": unset_profile,
                               "natural_new_profile_initialization_confirmed": False,
                               "note": "If initial equipment/cube values are undefined, this root seek is not proof "
                                       "of a fully initialized natural new save. Do not replace them with defaults in analysis."},
        "limits": [
            "Selection fields and root40 seek are fixture interventions; root40->41 and later initialization are original.",
            "Held isDown readback does not dispatch clip keyDown.",
            "F load and D directly seek parent frames; MP/CD input gates are not tested.",
            "F throw writes mirror explicitly labelled HUD entry effects, not actual handler invocation.",
            "8495 effects are replayed, not an OS button click.",
            "Actor/slot frames and host milliseconds are recorded separately; no 25Hz wall-time is assumed.",
            "Most ordinary slots were already ready; their arbitrary non-ready CD reset is not proved by this fixture.",
            "Initial profile values are observed as-is; this fixture does not call the original root.onLoad nor repair defaults.",
        ],
        "profile": profiles,
        "checks": checks, "finish": finish,
        "y_first_ready": y_event,
        "cube_floor_observations": [compact(row, ("cubes", "cube_floor_root", "cube_floor_root_type",
                                                   "cube_floor_player", "cube_floor_player_type"))
                                    for row in states if row.get("tag") in ("after_root40", "final")
                                    or (row.get("tag") == "tick" and row["t"] in (40, 60, 575, 650, 675, 700))],
        "f_original_load_stock": finish.get("loaded_stock") if finish else None,
        "f_first_observed_icon_ready_after_throw": compact(icon_resumes[0]) if icon_resumes else None,
        "reset_idle": reset_window("reset_idle", states, events),
        "reset_D": reset_window("reset_D", states, events),
        "events": events,
        "states": states,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--log", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    report = analyze(args.log)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2, allow_nan=False) + "\n", encoding="utf-8")
    print(json.dumps({"output": str(args.output), "integrity": report["integrity"],
                      "finish": report["finish"], "y_first_ready": report["y_first_ready"],
                      "f_icon_ready": report["f_first_observed_icon_ready_after_throw"]}, ensure_ascii=False))
    return 0 if report["integrity"]["ok"] else 2


if __name__ == "__main__":
    raise SystemExit(main())
