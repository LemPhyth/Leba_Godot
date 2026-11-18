"""Actual GL verification with frozen inputs, Dummy audio and strict log gating."""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
import subprocess

import run_act06_checks

runner = run_act06_checks.runner
GROUPS = {
    "world": {"field_d", "field_f", "field_g", "field_h", "w", "t", "r", "e", "y", "root9"},
    "actions": {"x", "a_early", "a_ghost1", "a_ghost2", "a_ghost3", "s", "z", "hurt_z", "q", "v_contact", "v_empty", "air", "kalla_air", "w_move"},
}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--name", required=True)
    parser.add_argument("--suite", required=True, choices=GROUPS)
    parser.add_argument("--groups", nargs="+")
    parser.add_argument("--timeout", type=float, default=240)
    args = parser.parse_args()
    if not re.fullmatch(r"[A-Za-z0-9_-]+", args.name):parser.error("Use a new simple evidence directory name")
    if args.groups and (set(args.groups) - GROUPS[args.suite]):parser.error("Unknown selected source group")
    if not 0 < args.timeout < 1800:parser.error("Timeout must be positive and below1800 seconds")
    out = runner.ARTIFACT_BASE / args.name
    if out.exists():parser.error("Evidence directory already exists; choose another --name")
    runner.FROZEN_FILES += ("tools/run_act06_gpu.py",)
    formal = runner.formal_profile_path()
    before = runner.snapshot(formal)
    out.mkdir(parents=True)
    runner.write_json(out / "before.json", before)
    env = os.environ.copy()
    env.update({"LEBA_TEST_MODE":"1", "LEBA_SILENT_TEST":"1", "LEBA_TEST_PROFILE":f"user://act06_gpu/{args.name}/profile.json", "LEBA_TEST_ARTIFACT_DIR":runner.res_path(out)})
    # Explicitly clear inherited partial-run filters before choosing this run.
    env.pop("LEBA_WORLD_RENDER_CASES", None)
    env.pop("LEBA_ACTION_RENDER_CASES", None)
    if args.groups:env["LEBA_WORLD_RENDER_CASES" if args.suite == "world" else "LEBA_ACTION_RENDER_CASES"] = ",".join(args.groups)
    command = [str(runner.GODOT), "--audio-driver", "Dummy", "--rendering-method", "gl_compatibility", "--path", str(runner.PROJECT), "--script", f"tests/render_act06_crt4_{args.suite}.gd", "--", "--test-mode", "--mute-audio"]
    startup = None
    creationflags = 0
    if os.name == "nt":
        startup = subprocess.STARTUPINFO()
        startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
        startup.wShowWindow = subprocess.SW_HIDE
        creationflags = subprocess.CREATE_NO_WINDOW | subprocess.CREATE_NEW_PROCESS_GROUP
    result = {"started_utc":runner.utc_now(), "command":command, "scope":"Real GL framebuffer and production input/source/ms chains; Dummy audio. Image review and audible listening remain separate.", "requested_groups":args.groups or "all", "exit_code":None, "timed_out":False, "cleanup":None, "passed":False}
    runner.write_json(out / "result.json", result)
    with (out / "stdout.log").open("wb") as stdout, (out / "stderr.log").open("wb") as stderr:
        process = subprocess.Popen(command, cwd=runner.PROJECT, env=env, stdout=stdout, stderr=stderr, startupinfo=startup, creationflags=creationflags)
        result["owned_pid"] = process.pid
        runner.write_json(out / "result.json", result)
        try:result["exit_code"] = process.wait(timeout=args.timeout)
        except (subprocess.TimeoutExpired, KeyboardInterrupt) as error:
            result["timed_out"] = isinstance(error, subprocess.TimeoutExpired)
            result["interrupted"] = isinstance(error, KeyboardInterrupt)
            result["cleanup"] = runner.stop_owned_tree(process, out)
    result["logs"] = runner.inspect_logs(out, "act06_gpu")
    report_path = out / "review.json"
    if report_path.is_file():
        report = json.loads(report_path.read_text(encoding="utf-8"))
        result["checks"] = len(report.get("checks", []))
        result["failures"] = sum(not row["passed"] for row in report.get("checks", []))
        result["cases"] = len(report.get("cases", []))
        result["pairs"] = len(report.get("pairs", []))
        result["renderer"] = report.get("renderer")
        result["adapter"] = report.get("adapter")
    else:result["report_missing"] = True
    after = runner.snapshot(formal)
    runner.write_json(out / "after.json", after)
    result["changed_during_run"] = runner.differences(before, after)
    result["finished_utc"] = runner.utc_now()
    result["passed"] = result["exit_code"] == 0 and not result["timed_out"] and not result.get("interrupted") and not result.get("report_missing") and result.get("checks", 0) > 0 and result.get("pairs", 0) > 0 and result.get("failures", -1) == 0 and not result["logs"]["errors"] and result["logs"]["warning_policy_passed"] and not result["changed_during_run"]["files"] and not result["changed_during_run"]["formal_profile_changed"]
    runner.write_json(out / "result.json", result)
    print(json.dumps({key:result.get(key) for key in ("passed", "checks", "failures", "cases", "pairs", "exit_code", "owned_pid")}, ensure_ascii=False))
    return 0 if result["passed"] else 1


if __name__ == "__main__":raise SystemExit(main())
