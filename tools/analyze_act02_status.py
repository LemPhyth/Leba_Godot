"""Read controlled original-SWF status traces, preserving unknown/missing values."""
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


def numeric(value):
    return isinstance(value, (int, float)) and not isinstance(value, bool)


def changes(rows, fields):
    result, previous = [], None
    for row in rows:
        state = tuple(row.get(k) for k in fields)
        if state != previous:
            result.append({k: row.get(k) for k in ("t", "ms", "raw_line", *fields)})
            previous = state
    return result


def analyze(log):
    raw = log.read_bytes()
    records, source_ticks, stop_lines = [], [], []
    for line_number, line in enumerate(raw.decode("utf-8-sig").splitlines(), 1):
        if "LEIBA_FIXTURE_DONE" in line:
            stop_lines.append(line_number)
        if "LEIBA02|" in line:
            fields = dict(part.split("=", 1) for part in line.split("LEIBA02|", 1)[1].split("|") if "=" in part)
            if "t" in fields:
                source_ticks.append(scalar(fields["t"]))
        if "ACT02_STATUS_" not in line:
            continue
        record_type, *parts = line.split("ACT02_STATUS_", 1)[1].split("|")
        row = {key: scalar(value) for key, value in (part.split("=", 1) for part in parts if "=" in part)}
        row.update(record_type=record_type, raw_line=line_number, order=len(records))
        records.append(row)
    checks = [r for r in records if r["record_type"] == "CHECK"]
    dones = [r for r in records if r["record_type"] == "DONE"]
    done = dones[-1] if dones else None
    errors = [f"Failed fixture check {r.get('name')}, tick {r.get('t')}, raw line {r['raw_line']}"
              for r in checks if r.get("ok") is not True]
    if len(dones) != 1:
        errors.append(f"Expected one DONE record, found {len(dones)}")
    if not stop_lines:
        errors.append("LEIBA_FIXTURE_DONE absent")
    if done and done.get("Key_unchanged") is not True:
        errors.append("Key object/function identity changed")
    launch_file = log.parent.parent / "launch.json"
    launch = json.loads(launch_file.read_text(encoding="utf-8-sig")) if launch_file.exists() else None
    if launch and launch.get("original_sha256_before") != launch.get("original_sha256_after"):
        errors.append("Original SHA256 after-hash absent or changed")
    states = [r for r in records if r["record_type"] == "STATE" and r.get("tag") == "tick"]
    grouped = defaultdict(list)
    for row in states:
        grouped[row["case"]].append(row)
    cases = {}
    for case, rows in grouped.items():
        damage = []
        for before, after in zip(rows, rows[1:]):
            if numeric(before.get("ehp")) and numeric(after.get("ehp")) and before["ehp"] != after["ehp"]:
                damage.append({"from_tick": before["t"], "to_tick": after["t"], "before": before["ehp"],
                               "after": after["ehp"], "delta": after["ehp"] - before["ehp"], "raw_line": after["raw_line"],
                               "sampled_marker": after.get("air_marker"), "sampled_ice": after.get("ice"),
                               "sampled_inner": after.get("inner"), "sampled_skull": after.get("skull"),
                               "sampled_sniper_marker": after.get("sniper_marker")})
        helper_groups = defaultdict(list)
        for row in records:
            if row["record_type"] == "HELPER" and row.get("case") == case:
                helper_groups[str(row.get("label"))].append(row)
        cases[case] = {
            "first": rows[0], "last": rows[-1], "hp_changes": damage,
            "status_transitions": changes(rows, ("actor", "action", "outer", "enemy", "ehp", "air_marker",
                                                    "ice", "ice_serial", "inner", "inner_serial", "skull",
                                                    "silver", "silver_serial", "eun", "sniper", "sniper_marker")),
            "helpers": {key: {"first_tick": rs[0]["t"], "last_tick": rs[-1]["t"],
                              "transitions": changes(rs, ("frame", "total", "normal", "frozen", "air"))}
                        for key, rs in helper_groups.items()},
        }
    specials = Counter(value for row in records for value in row.values()
                       if isinstance(value, str) and value in ("undefined", "NaN", "Infinity", "-Infinity"))
    return {"schema": "leba-act02-status-original-observation-v1",
            "evidence_class": "Controlled original SWF clips in Ruffle; not natural keyboard or native Adobe Flash",
            "log": str(log.resolve()), "sha256": hashlib.sha256(raw).hexdigest(), "launch": launch,
            "integrity": {"ok": not errors, "errors": errors, "counts": dict(Counter(r["record_type"] for r in records)),
                          "special_values": dict(specials), "done_lines": stop_lines,
                          "last_source_tick": source_ticks[-1] if source_ticks else None,
                          "extra_source_ticks_after_DONE": max(0, source_ticks[-1] - done["t"]) if source_ticks and done else None},
            "limits": ["HP2000, positions, independent status resets, direct actor/choice seeks and reticle aiming are explicit fixture interventions.",
                       "Fixture schema1 explicitly seeks freeze63; schema2 uses the actual H-frozen target and resets HP only. Schema records preserve this difference.",
                       "Original1474 attaches at fixture positions: schema1 parent center minus30 missed; schema2 aligns original helper center to target minus25. Natural X input/spawn is not tested.",
                       "Source AS, Key, Math.random and damage markers are not replaced.",
                       "Snapshots precede remaining queued callbacks; sampled frame is not necessarily the earlier frame read by a damage observer.",
                       "Damage deltas include all surviving source observers, not one copied coefficient.",
                       "Undefined/NaN remain strings; failed coverage is preserved and never imputed."],
            "checks": checks, "finish": done, "cases": cases, "records": records}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--log", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    result = analyze(args.log)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(result, ensure_ascii=False, indent=2, allow_nan=False) + "\n", encoding="utf-8")
    print(json.dumps({"out": str(args.out), "integrity": result["integrity"],
                      "damage": {k: v["hp_changes"] for k, v in result["cases"].items()}}, ensure_ascii=False))
    raise SystemExit(0 if result["integrity"]["ok"] else 1)


if __name__ == "__main__":
    main()
