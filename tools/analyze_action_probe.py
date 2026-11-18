"""Read controlled Ruffle action-fixture traces; never launch or modify the game.

This is original-clip timing evidence under scripted goto/seek calls, not natural
keyboard gameplay or native Adobe Flash verification. Undefined fields remain
explicit strings rather than silently becoming zero or a valid frame number.
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
DEFAULT_LOG = WORKSPACE / "tools/swf/runtime_probe/leiba02_timing_fixture/run1/log/ruffle.log"
DEFAULT_OUTPUT = PROJECT / "artifacts/leiba02_20261112/action_probe.json"
PREFIX = re.compile(r"avm_trace:\s+(LEIBA02_DETAIL|LEIBA02|LEIBA_FIXTURE)(?:\||$)")
DONE = re.compile(r"avm_trace:\s+LEIBA_FIXTURE_DONE\s*$")
CASE_SCHEDULE = [
    ("crt0_x1", 60, 100, 0, 7, 1),
    ("crt0_s", 100, 140, 0, 11, 1),
    ("crt0_d", 140, 180, 0, 13, 1),
    ("crt0_x2", 180, 220, 0, 8, 1),
    ("crt0_x3", 220, 260, 0, 9, 1),
    ("crt0_x5", 260, 300, 0, 16, 1),
    ("crt0_x6", 300, 340, 0, 10, 1),
    ("crt0_hit", 340, 380, 0, 14, 1),
    ("crt0_hit_same_parent_goto", 342, 380, 0, 14, 1),
    ("crt0_explicit_hurt_seek", 348, 380, 0, 14, 1),
    ("crt1_root_rebuild", 380, 410, 1, None, 30),
    ("crt1_x1", 410, 450, 1, 37, 30),
    ("crt1_s", 450, 490, 1, 42, 30),
    ("crt1_hit", 490, 530, 1, 44, 30),
]
SAMPLE_FIELDS = ("t", "root", "crt", "actor", "action", "hurt", "hp", "mp", "ehp", "hit", "enemy", "outer", "air", "gravity", "gacc")


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def parse_value(raw: str):
    if raw in {"undefined", "null", "NaN", "Infinity", "-Infinity"}:
        return raw
    try:
        value = float(raw)
    except ValueError:
        return raw
    if not math.isfinite(value):
        return raw
    return int(value) if value.is_integer() else value


def parse_fields(message: str) -> dict:
    return {key: parse_value(value) for key, value in
            (piece.split("=", 1) for piece in message.split("|") if "=" in piece)}


def numeric_changes(rows: list[dict], field: str, before: dict | None) -> list[dict]:
    previous = before
    changes = []
    for row in rows:
        if previous is not None:
            old, new = previous.get(field), row.get(field)
            if isinstance(old, (int, float)) and isinstance(new, (int, float)) and old != new:
                changes.append({"tick": row["t"], "previous_tick": previous["t"],
                                "before": old, "after": new, "delta": round(new - old, 10)})
        previous = row
    return changes


def analyze(log_path: Path, generator_path: Path) -> dict:
    # Snapshot once: a concurrently appended log cannot produce mixed parse/hash input.
    raw = log_path.read_bytes()
    frames: dict[int, dict] = {}
    interventions = []
    duplicates = []
    done_lines = []
    for line_no, line in enumerate(raw.decode("utf-8-sig", errors="replace").splitlines(), 1):
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
        if match[1] == "LEIBA_FIXTURE":
            interventions.append({**data, "log_line": line_no})
            continue
        entry = frames.setdefault(tick, {"t": tick, "records": {}, "log_lines": []})
        kind = "detail" if match[1] == "LEIBA02_DETAIL" else "base"
        if kind in entry["records"]:
            duplicates.append({"tick": tick, "kind": kind, "line": line_no})
        entry["records"][kind] = data
        entry["log_lines"].append(line_no)
    merged = {}
    for tick, entry in frames.items():
        merged[tick] = {**entry["records"].get("base", {}),
                        **entry["records"].get("detail", {}),
                        "log_lines": entry["log_lines"]}
    missing = [tick for tick in range(60, 531)
               if tick not in frames or set(frames[tick]["records"]) != {"base", "detail"}]
    complete = bool(done_lines) and not missing and not duplicates
    probe_directory = log_path.parents[2]
    provenance_path = probe_directory / "provenance.json"
    observer_path = probe_directory / "observer.as"
    provenance = json.loads(provenance_path.read_text(encoding="utf-8")) if provenance_path.exists() else None
    observer_hash = sha256(observer_path.read_bytes()) if observer_path.exists() else None
    if provenance and provenance.get("observer_sha256") != observer_hash:
        complete = False
    cases = []
    for name, start, until, character, target, idle in CASE_SCHEDULE:
        rows = [merged[tick] for tick in range(start, until) if tick in merged]
        prior = merged.get(start - 1)
        return_row = next((row for row in rows if row["t"] > start and row.get("actor") == idle), None)
        active = [row for row in rows if return_row is None or row["t"] < return_row["t"]]
        cases.append({
            "case": name, "fixture_tick": start, "until_exclusive": until,
            "fixture_operation": "seek_hurt=2" if name.endswith("hurt_seek") else
                                 "rebuild_root=2" if target is None else f"goto_player_parent={target}",
            "expected_character_from_schedule": character,
            "expected_active_parent_from_schedule": target, "return_parent": idle,
            "observed_start": merged.get(start),
            "first_return_parent_tick": return_row["t"] if return_row else None,
            "ticks_until_return_observation": return_row["t"] - start if return_row else None,
            "entry_to_return_inclusive_samples": return_row["t"] - start + 1 if return_row else None,
            "action_sequence_before_return": [row.get("action", "missing") for row in active],
            "hurt_sequence_before_return": [row.get("hurt", "missing") for row in active],
            "hp_changes": numeric_changes(rows, "hp", prior),
            "enemy_hp_changes": numeric_changes(rows, "ehp", prior),
            "interventions": [event for event in interventions if start <= event["t"] < until],
            "timeline": [{field: row.get(field, "missing") for field in SAMPLE_FIELDS} |
                         {"log_lines": row["log_lines"]} for row in rows],
            "complete_window": all(tick in frames and set(frames[tick]["records"]) == {"base", "detail"}
                                   for tick in range(start, until)),
        })
    return {
        "schema_version": 1, "complete": complete,
        "evidence_kind": "controlled_Ruffle_original_clip_calls_NOT_natural_keyboard",
        "sampling": "Fixture executes before base/detail trace in observer onEnterFrame; samples are not display-frame screenshots.",
        "source_fps": 25, "done_expected_tick": 530, "done_marker_lines": done_lines,
        "done_tick_has_both_records": 530 in frames and set(frames[530]["records"]) == {"base", "detail"},
        "max_observed_tick": max(frames, default=None),
        "missing_base_or_detail_ticks": missing, "duplicate_records": duplicates,
        "log_snapshot": {"path": str(log_path.resolve()), "sha256": sha256(raw), "bytes": len(raw)},
        "generator": {"path": str(generator_path.resolve()), "sha256": sha256(generator_path.read_bytes())},
        "probe_provenance": provenance, "observer_sha256": observer_hash,
        "limitations": [
            "Fixture changes character/root/player timeline directly and bypasses keyboard gates, resource cost and cooldown startup.",
            "Same-parent goto at342 and explicit hurt seek at348 intervene in the crt0 hit case; it is not an isolated natural hit.",
            "Character rebuild at380 retains other original state unless source script resets it; it is not a clean new-game comparison.",
            "Trace sampling follows fixture calls and may omit same-tick control frames; durations describe the sampled fixture execution.",
            "Elapsed tick intervals differ from inclusive entry/return sample counts by one; neither counts an omitted control frame as an extra visible pose.",
            "Original Adobe Flash dispatch, ordinary collision-triggered player damage and keyboard repeat ordering are not verified here.",
        ],
        "cases": cases,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--log", type=Path, default=DEFAULT_LOG)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--generator", type=Path, default=PROJECT / "tools/build_runtime_probe.py")
    args = parser.parse_args()
    if args.output.resolve() in {args.log.resolve(), args.generator.resolve()}:
        parser.error("Output must be a separate derived report, never an input file.")
    result = analyze(args.log, args.generator)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2, allow_nan=False) + "\n", encoding="utf-8")
    print(json.dumps({"complete": result["complete"], "cases": len(result["cases"]),
                      "missing_ticks": len(result["missing_base_or_detail_ticks"]), "output": str(args.output)}))
    for case in result["cases"]:
        print(json.dumps({key: case[key] for key in ("case", "fixture_tick", "first_return_parent_tick", "action_sequence_before_return", "hurt_sequence_before_return", "hp_changes")}))


if __name__ == "__main__":
    main()
