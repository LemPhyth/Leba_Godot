"""Summarize real M1 Z timer traces without synthesizing missing observations.

This is a log reader, not a gameplay simulator. Original raw lines, line numbers,
requested delays, observed elapsed milliseconds, and instrumentation boundaries
remain separate. Run with --log PATH --output PATH.
"""
import argparse
from collections import Counter, defaultdict
import hashlib
import json
from pathlib import Path
from statistics import median


def value(text):
    if text == "undefined":
        return None
    try:
        number = float(text)
        return int(number) if number.is_integer() else number
    except ValueError:
        return text


def stats(numbers):
    if not numbers:
        return {"count": 0}
    return {"count": len(numbers), "min": min(numbers),
            "median": median(numbers), "max": max(numbers)}


def analyze(log):
    raw = log.read_bytes()
    lines = raw.decode("utf-8-sig").splitlines()
    events = []
    for line_no, line in enumerate(lines, 1):
        if "LEBA_M1_Z_TIMER|" not in line:
            continue
        record = {key: value(item) for key, item in
                  (field.split("=", 1) for field in
                   line.split("LEBA_M1_Z_TIMER|", 1)[1].split("|") if "=" in field)}
        record["raw_line"] = line_no
        record["order"] = len(events)
        events.append(record)
    intervals = {}
    timeouts = {}
    waiting = {}
    callbacks = []
    interval_deltas = []
    integrity_errors = []
    finished_timeouts = set()
    for event in events:
        kind = event["event"]
        timer_id = event.get("id")
        if kind == "interval_create":
            intervals[timer_id] = {"created": event, "callbacks": [], "clears": []}
        elif kind == "timeout_create":
            timeouts[timer_id] = {"created": event, "fired": None, "clears_during_callback": []}
        elif kind == "interval_before":
            if timer_id in waiting:
                integrity_errors.append(f"Interval {timer_id} has an unmatched before at line {waiting[timer_id]['raw_line']}")
            waiting[timer_id] = event
        elif kind == "interval_after":
            before = waiting.pop(timer_id, None)
            if before is None:
                integrity_errors.append(f"Interval {timer_id} has an orphan after at line {event['raw_line']}")
                continue
            callback = {"id": timer_id, "before": before, "after": event,
                        "enemy_dx": round(event["ex"] - before["ex"], 9),
                        "enemy_hp_delta": event["hp"] - before["hp"]}
            callbacks.append(callback)
            if timer_id in intervals:
                intervals[timer_id]["callbacks"].append(callback)
        elif kind == "interval_clear":
            if timer_id in intervals:
                intervals[timer_id]["clears"].append(event)
        elif kind == "timeout_before" and timer_id in timeouts:
            timeouts[timer_id]["fired"] = event
        elif kind == "timeout_after":
            finished_timeouts.add(timer_id)
    for timer_id, before in waiting.items():
        integrity_errors.append(f"Interval {timer_id} has an unmatched before at line {before['raw_line']}")
    for timer_id, timeout in timeouts.items():
        if timeout["fired"] is None or timer_id not in finished_timeouts:
            integrity_errors.append(f"Timeout {timer_id} has no complete callback pair")
    for interval in intervals.values():
        calls = interval["callbacks"]
        times = [call["before"]["ms"] for call in calls]
        deltas = [later - earlier for earlier, later in zip(times, times[1:])]
        interval_deltas.extend(deltas)
        interval["callback_count"] = len(calls)
        interval["first_callback_elapsed_ms"] = times[0] - interval["created"]["ms"] if times else None
        interval["callback_spacing_ms"] = stats(deltas)
        interval["callback_spacing_histogram"] = dict(sorted(Counter(deltas).items()))
        interval["total_callback_enemy_dx"] = round(sum(c["enemy_dx"] for c in calls), 9)
        interval["callback_after_original_child_removed"] = any(c["before"].get("child") is None for c in calls)
    for timeout in timeouts.values():
        fired = timeout["fired"]
        if fired is None:
            timeout["elapsed_ms"] = None
            continue
        timeout["elapsed_ms"] = fired["ms"] - timeout["created"]["ms"]
        for later in events[fired["order"] + 1:]:
            if later["event"] == "timeout_after" and later.get("id") == fired["id"]:
                break
            if later["event"] == "interval_clear":
                timeout["clears_during_callback"].append(later)
        timeout["clears_newer_interval"] = any(
            clear.get("id") in intervals and
            intervals[clear["id"]]["created"]["order"] > timeout["created"]["order"]
            for clear in timeout["clears_during_callback"])
    samples = [event for event in events if event["event"] == "tick_sample"]
    hp_changes = []
    previous = None
    for sample in samples:
        if previous and sample.get("hp") != previous.get("hp"):
            hp_changes.append({"before": previous, "after": sample,
                               "enemy_hp_delta": sample["hp"] - previous["hp"]})
        previous = sample
    phases = defaultdict(list)
    for call in callbacks:
        phases[call["before"].get("phase")].append(call)
    phase_summary = {}
    for phase, calls in phases.items():
        phase_summary[phase] = {
            "callbacks": len(calls), "callback_enemy_dx_total": round(sum(c["enemy_dx"] for c in calls), 9),
            "callback_dx_values": sorted(set(c["enemy_dx"] for c in calls)),
            "callback_hp_delta_values": sorted(set(c["enemy_hp_delta"] for c in calls)),
            "calls_after_child_removed": sum(c["before"].get("child") is None for c in calls),
            "first": calls[0]["before"], "last": calls[-1]["after"]}
    return {
        "evidence_kind": "Ruffle 0.7.1 controlled fixture with forwarding timer wrappers; not native Flash or natural keyboard",
        "log": str(log.resolve()), "sha256": hashlib.sha256(raw).hexdigest(),
        "done": any("LEIBA_FIXTURE_DONE" in line for line in lines),
        "wrappers_restored": any(e["event"] == "wrappers_restored" for e in events),
        "event_counts": dict(Counter(e["event"] for e in events)),
        "integrity_errors": integrity_errors,
        "warnings": [{"raw_line": i, "text": line} for i, line in enumerate(lines, 1) if " WARN " in line],
        "errors": [{"raw_line": i, "text": line} for i, line in enumerate(lines, 1) if " ERROR " in line],
        "callback_spacing_ms": stats(interval_deltas),
        "callback_spacing_histogram": dict(sorted(Counter(interval_deltas).items())),
        "phase_summary": phase_summary,
        "intervals": intervals, "timeouts": timeouts,
        "enemy_hp_changes": hp_changes,
        "ground_first_air_samples": [s for s in samples if 103 <= s["t"] <= 114],
        "all_events": events,
        "limitations": [
            "t is the observer's most recent tick; use raw order, ms, and child frame for events before its next increment.",
            "Requested 10/500 ms and observed getTimer differences are distinct; initial callback catch-up and early timeout are reported as observed.",
            "Fixture-created air at t60 already starts a natural marker; its HP loss before Z callbacks is not a Z contact.",
            "No overlap trace was inserted inside the original hitTest; far-target/no-hit inference also uses source geometry and unchanged gacc.",
            "Wrappers add function calls and trace cost, while forwarding original callback references, this, and arguments."]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--log", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    result = analyze(args.log)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({"output": str(args.output), "done": result["done"],
                      "event_counts": result["event_counts"], "spacing_ms": result["callback_spacing_ms"],
                      "timeout_elapsed_ms": [v["elapsed_ms"] for v in result["timeouts"].values()],
                      "error_count": len(result["errors"]), "warning_count": len(result["warnings"]),
                      "integrity_errors": result["integrity_errors"]}, ensure_ascii=False))
    return 0 if (result["done"] and result["wrappers_restored"] and result["intervals"] and
                 result["timeouts"] and not result["errors"] and not result["integrity_errors"]) else 1


if __name__ == "__main__":
    raise SystemExit(main())
