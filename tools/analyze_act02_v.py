"""Parse the controlled original V action without inventing capture or hit results."""
from __future__ import annotations

import argparse
from collections import Counter, defaultdict
import hashlib
import json
from pathlib import Path

from analyze_act02_status import changes, numeric, scalar


def analyze(log):
    raw = log.read_bytes()
    records, stop_lines, source_ticks = [], [], []
    for line_number, line in enumerate(raw.decode("utf-8-sig").splitlines(), 1):
        if "LEIBA_FIXTURE_DONE" in line:
            stop_lines.append(line_number)
        if "LEIBA02|" in line:
            fields = dict(part.split("=", 1) for part in line.split("LEIBA02|", 1)[1].split("|") if "=" in part)
            if "t" in fields:
                source_ticks.append(scalar(fields["t"]))
        if "ACT02_V_" not in line:
            continue
        record_type, *parts = line.split("ACT02_V_", 1)[1].split("|")
        row = {key: scalar(value) for key, value in (part.split("=", 1) for part in parts if "=" in part)}
        row.update(record_type=record_type, raw_line=line_number, order=len(records))
        if record_type == "HELPER":
            frame = row.get("action")
            # v1's depth137 label also covered unrelated early visual clips.
            # Preserve the raw label; resolve only the verified XML windows.
            repeated = frame in [26, 27, 30, 31, 34, 35, 38, 39, 42, 43, 46, 47,
                                 50, 51, 54, 55, 58, 59, 62, 63, 66, 67]
            final = frame in [69, 70]
            if row.get("depth") == -16247:
                row["verified_source_id"] = 651 if repeated else "not651_visual"
            elif row.get("depth") == -16249:
                row["verified_source_id"] = 651 if final else 5652 if numeric(frame) and 15 <= frame < 68 else "unresolved"
            elif row.get("depth") == -16289:
                row["verified_source_id"] = 1234
        records.append(row)
    checks = [r for r in records if r["record_type"] == "CHECK"]
    dones = [r for r in records if r["record_type"] == "DONE"]
    done = dones[-1] if dones else None
    errors = [f"Failed {r.get('name')} at tick {r.get('t')} raw line {r['raw_line']}"
              for r in checks if r.get("ok") is not True]
    if len(dones) != 1 or not stop_lines:
        errors.append("Missing or duplicate completion records")
    if done and done.get("Key_unchanged") is not True:
        errors.append("Original Key identity changed")
    verified_651 = [r for r in records if r["record_type"] == "HELPER" and r.get("verified_source_id") == 651]
    if not verified_651:
        errors.append("No XML-verified651 window observed; raw depth137 is insufficient")
    launch_file = log.parent.parent / "launch.json"
    launch = json.loads(launch_file.read_text(encoding="utf-8-sig")) if launch_file.exists() else None
    if launch and launch.get("original_sha256_before") != launch.get("original_sha256_after"):
        errors.append("Original SWF after-hash absent or changed")
    groups = defaultdict(list)
    for row in records:
        if row["record_type"] == "STATE" and row.get("tag") == "tick":
            groups[row["case"]].append(row)
    cases = {}
    for case, rows in groups.items():
        hp_changes = []
        for a, b in zip(rows, rows[1:]):
            if numeric(a.get("ehp")) and numeric(b.get("ehp")) and a["ehp"] != b["ehp"]:
                hp_changes.append({"from_tick": a["t"], "to_tick": b["t"], "before": a["ehp"],
                                   "after": b["ehp"], "delta": b["ehp"] - a["ehp"], "raw_line": b["raw_line"],
                                   "sampled_action": b.get("action"), "sampled_marker": b.get("marker")})
        anchors = []
        for row in rows:
            if row.get("anchor_active") is True:
                anchors.append({k: row.get(k) for k in ("t", "raw_line", "action", "zab", "pren", "child_x", "child_y",
                                                        "anchor_x", "anchor_y", "formula_x", "formula_y", "ex", "ey", "g", "gacc")})
        cases[case] = {"first": rows[0], "last": rows[-1], "hp_changes": hp_changes, "anchor_samples": anchors,
                       "transitions": changes(rows, ("actor", "action", "zab", "pren", "outer", "enemy", "marker", "ehp")),
                       "helper_rows": [r for r in records if r["record_type"] == "HELPER" and r.get("case") == case]}
    return {"schema": "leba-act02-v-original-observation-v1",
            "evidence_class": "Controlled original SWF in Ruffle; not natural keyboard or Adobe Flash",
            "log": str(log.resolve()), "sha256": hashlib.sha256(raw).hexdigest(), "launch": launch,
            "integrity": {"ok": not errors, "errors": errors, "counts": dict(Counter(r["record_type"] for r in records)),
                          "special_values": dict(Counter(v for r in records for v in r.values()
                                                         if isinstance(v, str) and v in ("undefined", "NaN", "Infinity", "-Infinity"))),
                          "done_lines": stop_lines, "last_source_tick": source_ticks[-1] if source_ticks else None,
                          "extra_source_ticks_after_DONE": max(0, source_ticks[-1] - done["t"]) if source_ticks and done else None},
            "limits": ["Direct parent98 seeks bypass input, cost and cooldown. HP2000/positions/gravity/baseline zab0/pren0 are declared interventions.",
                       "No capture result, success goto15, marker, damage coefficient or anchor coordinate is forced during actions.",
                       "Computed anchor formula is read-only source arithmetic, not a write to the enemy.",
                       "State snapshots occur before remaining queued callbacks; matching same-tick positions is not assumed.",
                       "v1 raw shot/first651 fields mean depth137 existence, including earlier visual clips. HELPER verified_source_id applies XML/catalog651 windows; raw labels remain unchanged.",
                       "No multi-enemy selection order, reversed facing, frozen/armor or interruption case is covered by this minimal fixture."],
            "verified_first651": verified_651[0] if verified_651 else None,
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
