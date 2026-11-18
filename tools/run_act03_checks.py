"""Run 21 ACT03 regression suites sequentially with silent, isolated evidence.

Preserves existing run directories. Hashes runtime code/data, author content,
scenes, generated resources, catalog-referenced assets and the formal profile
family before/after each suite. Does not import, regenerate or repair content.
Services' seven explicit audio-negative-case warnings are recorded separately;
any other warning or engine/script error fails the corresponding suite.
"""
from __future__ import annotations

import argparse
from collections import Counter
import configparser
from datetime import datetime, timezone
import hashlib
import json
import math
import os
from pathlib import Path
import re
import signal
import subprocess
import sys
import time
from typing import Any

PROJECT = Path(__file__).resolve().parents[1]
ARTIFACT_BASE = PROJECT / "artifacts/leba_act03_20261116"
GODOT = PROJECT.parent / "tools/Godot_v4.6.3-stable_mono_win64/Godot_v4.6.3-stable_mono_win64_console.exe"
OLD_SUITES = (
    "actions", "m1_actions", "hit_timeline", "gameplay", "services", "progression",
    "act02_training", "act02_skills", "act02_status", "act02_v", "act02_t",
    "act02_y", "act02_y_source", "act02_ammo", "act02_menu", "act02_integration",
)
NEW_SUITES = ("act03_crt1", "act03_flow", "act03_ui", "act03_focus", "act03_editing")
SUITES = OLD_SUITES + NEW_SUITES
LAB_SUITES = {
    "actions", "m1_actions", "hit_timeline", "act02_training", "act02_skills",
    "act02_status", "act02_v", "act02_t", "act02_ammo",
}
FROZEN_DIRECTORIES = ("scripts", "data", "tests", "content", "scenes", "generated")
FROZEN_FILES = ("project.godot", "tools/run_act03_checks.py", "tools/sync_generated_animations.gd")
EXPECTED_SERVICE_WARNINGS = Counter({
    "missing_alias": 1, "missing_resource": 1, "invalid_offset": 3,
    "offset_at_end": 1, "offset_after_end": 1,
})
ANSI = re.compile(r"\x1b\[[0-?]*[ -/]*[@-~]")


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def write_json(path: Path, value: Any) -> None:
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def res_path(path: Path) -> str:
    return "res://" + path.resolve().relative_to(PROJECT).as_posix()


def formal_profile_path() -> Path:
    """Resolve this project's Godot user:// without launching the engine."""
    config = configparser.ConfigParser(interpolation=None, strict=False)
    # Godot has an unsectioned config_version and Variant-valued sections;
    # only the scalar application section is INI-compatible.
    text = (PROJECT / "project.godot").read_text(encoding="utf-8")
    section = re.search(r"^\[application\]\s*$(.*?)(?=^\[|\Z)", text, re.MULTILINE | re.DOTALL)
    if section is None:
        raise ValueError("project.godot has no application section")
    config.read_string("[application]\n" + section[1])
    application = config["application"]
    name = json.loads(application.get("config/name", '"unnamed_project"'))
    custom = application.get("config/use_custom_user_dir", "false").strip() == "true"
    custom_name = json.loads(application.get("config/custom_user_dir_name", '""')) or name
    if os.name == "nt":
        base = Path(os.environ.get("APPDATA", str(Path.home() / "AppData/Roaming")))
    elif sys.platform == "darwin":
        base = Path.home() / "Library/Application Support"
    else:
        base = Path(os.environ.get("XDG_DATA_HOME", str(Path.home() / ".local/share")))
    if custom:
        return base / custom_name / "profile.json"
    godot_folder = "godot" if os.name != "nt" and sys.platform != "darwin" else "Godot"
    return base / godot_folder / "app_userdata" / name / "profile.json"


def profile_snapshot(path: Path) -> dict[str, Any]:
    family: dict[str, Any] = {}
    if path.parent.exists():
        for candidate in sorted(path.parent.iterdir()):
            if candidate.name == path.name or candidate.name.startswith(path.name + "."):
                family[candidate.name] = (
                    {"kind": "file", "bytes": candidate.stat().st_size, "sha256": sha256(candidate)}
                    if candidate.is_file() else {"kind": "directory" if candidate.is_dir() else "other"}
                )
    return {"path": str(path), "exists": path.exists(), "files": family}


def catalog_assets(catalog: Any) -> set[Path]:
    paths: set[Path] = set()
    if isinstance(catalog, dict):
        for value in catalog.values():
            paths.update(catalog_assets(value))
    elif isinstance(catalog, list):
        for value in catalog:
            paths.update(catalog_assets(value))
    elif isinstance(catalog, str) and catalog.startswith(("res://assets/", "assets/")):
        relative = catalog.removeprefix("res://")
        path = (PROJECT / relative).resolve()
        if not path.is_relative_to(PROJECT / "assets"):
            raise ValueError(f"Catalog asset escapes assets/: {catalog}")
        paths.add(path)
    return paths


def snapshot(formal: Path) -> dict[str, Any]:
    files: set[Path] = set()
    for directory in FROZEN_DIRECTORIES:
        base = PROJECT / directory
        if not base.is_dir():
            raise FileNotFoundError(f"Freeze directory missing: {base}")
        files.update(path for path in base.rglob("*") if path.is_file())
    files.update(PROJECT / name for name in FROZEN_FILES)
    catalog_file = PROJECT / "data/asset_catalog.json"
    assets = catalog_assets(json.loads(catalog_file.read_text(encoding="utf-8")))
    files.update(assets)
    hashes = {path.relative_to(PROJECT).as_posix(): sha256(path) for path in sorted(files)}
    return {
        "utc": utc_now(), "files_sha256": hashes, "file_count": len(hashes),
        "catalog_sha256": hashes["data/asset_catalog.json"],
        "catalog_asset_count": len(assets), "formal_profile": profile_snapshot(formal),
    }


def differences(before: dict[str, Any], after: dict[str, Any]) -> dict[str, Any]:
    old, new = before["files_sha256"], after["files_sha256"]
    return {
        "files": sorted(key for key in old.keys() | new.keys() if old.get(key) != new.get(key)),
        "formal_profile_changed": before["formal_profile"] != after["formal_profile"],
    }


def parse_result(stdout: str) -> tuple[dict[str, int] | None, str | None, str | None]:
    clean = ANSI.sub("", stdout)
    candidates = []
    for kind, pattern in (
        ("json", r"^\w+_RESULT\s+(\{[^\r\n]*\})\s*$"),
        ("legacy", r"^ACT03_(?:EDITING|FLOW)\s+checks=(\d+)\s+failures=(\d+)\s+report=(.+?)\s*$"),
        ("progression", r"^Progression: (\d+) passed / (\d+) failed\s*$"),
    ):
        candidates.extend((match.start(), kind, match) for match in re.finditer(pattern, clean, re.MULTILINE))
    report_path = None
    try:
        if not candidates:
            return None, None, "No recognized final result marker"
        _, kind, marker = max(candidates, key=lambda item: item[0])
        if kind == "json":
            result = json.loads(marker[1])
        elif kind == "legacy":
            checks, failures, report_path = marker.groups()
            result = {"checks": int(checks), "failures": int(failures)}
        else:
            result = {"checks": int(marker[1]) + int(marker[2]), "failures": int(marker[2])}
        checks, failures = result.get("checks"), result.get("failures")
        if type(checks) is not int or type(failures) is not int or checks <= 0 or not 0 <= failures <= checks:
            return None, report_path, f"Invalid final counts: {result!r}"
        return {"checks": checks, "failures": failures}, report_path, None
    except (ValueError, TypeError, AttributeError) as error:
        return None, report_path, f"Invalid result marker: {error}"


def service_warning_kind(message: str) -> str | None:
    if message == "音效未登记：missing":
        return "missing_alias"
    if message == "缺少音频资源 music/broken：res://does_not_exist.wav":
        return "missing_resource"
    if message == "音效播放起点必须是有限非负秒数：effect":
        return "invalid_offset"
    match = re.fullmatch(r"音效播放起点必须小于有效时长：effect，起点=([0-9.eE+\-]+)，时长=([0-9.eE+\-]+)", message)
    if match:
        offset, duration = map(float, match.groups())
        if math.isclose(duration, 0.1, rel_tol=0, abs_tol=1e-6):
            if math.isclose(offset, duration, rel_tol=0, abs_tol=1e-6):
                return "offset_at_end"
            if math.isclose(offset, duration + 1.0, rel_tol=0, abs_tol=1e-6):
                return "offset_after_end"
    return None


def inspect_logs(case: Path, suite: str) -> dict[str, Any]:
    errors, warnings, expected, unexpected = [], [], [], []
    observed: Counter[str] = Counter()
    scanned = []
    for path in sorted(case.rglob("*.log")):
        if path.name == "timeout_cleanup.log":
            continue
        scanned.append(path.relative_to(case).as_posix())
        for number, raw in enumerate(path.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
            line = ANSI.sub("", raw).strip()
            row = {"file": path.relative_to(case).as_posix(), "line": number, "text": line}
            if re.match(r"^(?:SCRIPT ERROR:|ERROR:|Parse Error:)", line):
                errors.append(row)
            if line.startswith("WARNING:"):
                warnings.append(row)
                kind = service_warning_kind(line.removeprefix("WARNING:").strip()) if suite == "services" else None
                if kind is not None and observed[kind] < EXPECTED_SERVICE_WARNINGS[kind]:
                    observed[kind] += 1
                    expected.append({**row, "fixture": kind})
                else:
                    unexpected.append(row)
    policy_ok = not unexpected and (suite != "services" or observed == EXPECTED_SERVICE_WARNINGS)
    return {
        "scanned_logs": scanned, "errors": errors, "warnings": warnings,
        "expected_negative_case_warnings": expected, "unexpected_warnings": unexpected,
        "expected_warning_counts": dict(EXPECTED_SERVICE_WARNINGS) if suite == "services" else {},
        "observed_expected_warning_counts": dict(observed), "warning_policy_passed": policy_ok,
    }


def stop_owned_tree(process: subprocess.Popen[bytes], case: Path) -> dict[str, Any]:
    """Stop only the PID created for this case, including its owned sync children."""
    if process.poll() is not None:
        return {"attempted": False, "completed": True}
    record: dict[str, Any] = {"attempted": True, "pid": process.pid}
    try:
        if os.name == "nt":
            command = ["taskkill.exe", "/PID", str(process.pid), "/T", "/F"]
            cleanup = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=15)
            (case / "timeout_cleanup.log").write_bytes(cleanup.stdout)
            record.update({"command": command, "exit_code": cleanup.returncode})
        else:
            os.killpg(process.pid, signal.SIGKILL)
            record["signal"] = "SIGKILL on this runner-created process group"
        process.wait(timeout=10)
    except (OSError, subprocess.TimeoutExpired) as error:
        record["error"] = str(error)
    record["completed"] = process.poll() is not None
    return record


def run_suite(name: str, out: Path, executable: Path, timeout: float) -> dict[str, Any]:
    case = out / name
    case.mkdir()
    flags = ["--test-mode", "--mute-audio"]
    if name in LAB_SUITES:
        flags.append("--action-lab")
    if name == "act03_flow":
        flags.append("--report=" + res_path(case / "report.json"))
    # Each subprocess receives its own entry profile. Suites may additionally
    # create private fixture profiles, but never receive the formal path.
    profile = f"user://act03_runner/{out.name}/{name}/profile.json"
    env = os.environ.copy()
    env.update({
        "LEBA_TEST_ARTIFACT_DIR": res_path(case), "LEBA_TEST_MODE": "1",
        "LEBA_SILENT_TEST": "1", "LEBA_TEST_PROFILE": profile,
    })
    command = [str(executable), "--headless", "--audio-driver", "Dummy", "--path", str(PROJECT),
               "--script", f"tests/test_{name}.gd", "--", *flags]
    row: dict[str, Any] = {
        "suite": name, "command": command, "environment": {key: env[key] for key in ("LEBA_TEST_ARTIFACT_DIR", "LEBA_TEST_MODE", "LEBA_SILENT_TEST", "LEBA_TEST_PROFILE")},
        "started_utc": utc_now(), "timeout_seconds": timeout, "timed_out": False,
        "exit_code": None, "execution_error": None, "cleanup": None,
    }
    write_json(case / "invocation.json", row)
    started = time.monotonic()
    process = None
    with (case / "stdout.log").open("wb") as stdout_file, (case / "stderr.log").open("wb") as stderr_file:
        try:
            options: dict[str, Any] = {"cwd": PROJECT, "env": env, "stdout": stdout_file, "stderr": stderr_file}
            if os.name == "nt":
                options["creationflags"] = subprocess.CREATE_NEW_PROCESS_GROUP | subprocess.CREATE_NO_WINDOW
            else:
                options["start_new_session"] = True
            process = subprocess.Popen(command, **options)
            row["pid"] = process.pid
            try:
                row["exit_code"] = process.wait(timeout=timeout)
            except subprocess.TimeoutExpired:
                row["timed_out"] = True
                row["cleanup"] = stop_owned_tree(process, case)
                row["exit_code"] = process.poll()
        except KeyboardInterrupt:
            row["execution_error"] = "Runner interrupted by user"
            if process is not None:
                row["cleanup"] = stop_owned_tree(process, case)
                row["exit_code"] = process.poll()
        except OSError as error:
            row["execution_error"] = str(error)
            if process is not None:
                row["cleanup"] = stop_owned_tree(process, case)
                row["exit_code"] = process.poll()
    row["elapsed_seconds"] = round(time.monotonic() - started, 3)
    stdout = (case / "stdout.log").read_text(encoding="utf-8", errors="replace")
    row["result"], row["reported_artifact"], row["result_parse_error"] = parse_result(stdout)
    row.update(inspect_logs(case, name))
    row["passed"] = (
        not row["timed_out"] and row["execution_error"] is None and row["exit_code"] == 0
        and row["result"] is not None and row["result"]["failures"] == 0
        and not row["errors"] and row["warning_policy_passed"]
    )
    write_json(case / "result.json", row)
    return row


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--name", required=True, help="New evidence subdirectory; existing names are never overwritten")
    parser.add_argument("--suites", nargs="+", choices=SUITES, help="Subset in the supplied order; default is 16 old + 5 ACT03 suites")
    parser.add_argument("--timeout", type=float, default=180.0, help="Maximum seconds per suite, including its subprocesses (default: 180)")
    parser.add_argument("--godot", type=Path, default=GODOT, help="Godot console executable")
    parser.add_argument("--formal-profile", type=Path, help="Optional explicit formal-profile path for read-only hash verification")
    args = parser.parse_args()
    if not re.fullmatch(r"[A-Za-z0-9_-]+", args.name):
        parser.error("--name must contain only letters, digits, underscores and hyphens")
    if not math.isfinite(args.timeout) or args.timeout <= 0:
        parser.error("--timeout must be finite and positive")
    names = list(args.suites or SUITES)
    if len(names) != len(set(names)):
        parser.error("A suite cannot occur twice in the same evidence run")
    executable = args.godot.expanduser().resolve()
    if not executable.is_file():
        parser.error(f"Godot executable not found: {executable}")
    missing = [name for name in names if not (PROJECT / f"tests/test_{name}.gd").is_file()]
    if missing:
        parser.error(f"Suite scripts missing: {missing}")
    formal = (args.formal_profile or formal_profile_path()).expanduser().resolve()
    out = ARTIFACT_BASE / args.name
    if out.exists():
        parser.error(f"Evidence directory already exists; choose another --name: {out}")
    # A missing/unreadable frozen input stops before launching any test.
    before = snapshot(formal)
    out.mkdir(parents=True, exist_ok=False)
    write_json(out / "before.json", before)
    record: dict[str, Any] = {
        "started_utc": utc_now(), "project": str(PROJECT), "godot_executable": str(executable),
        "godot_executable_sha256": sha256(executable), "requested_suites": names,
        "freeze_directories": list(FROZEN_DIRECTORIES), "freeze_files": list(FROZEN_FILES),
        "before": "before.json", "after": "after.json", "suites": [], "not_run": [],
        "passed": False, "abort_reason": None,
        "scope": "Sequential headless Godot with Dummy audio, isolated entry/fixture profiles, actual per-suite tests. No OS keyboard, GPU screenshot, audible listening, human-editor or original Adobe Flash acceptance is inferred. Original-comparison and fixture limits are stated by each suite.",
        "warning_policy": "Only the seven identified services audio-negative warnings are expected; each remains in logs and expected_negative_case_warnings. Other warnings, script/engine errors, missing final markers, timeouts, changed frozen bytes or formal-profile-family changes fail the run.",
    }
    write_json(out / "summary.json", record)
    for index, name in enumerate(names):
        try:
            case_before = snapshot(formal)
            before_changes = differences(before, case_before)
            if before_changes["files"] or before_changes["formal_profile_changed"]:
                record["abort_reason"] = {"reason": "Frozen inputs changed before suite", "suite": name, **before_changes}
                record["not_run"] = names[index:]
                break
            row = run_suite(name, out, executable, args.timeout)
            record["suites"].append(row)
            case_after = snapshot(formal)
            write_json(out / name / "after.json", case_after)
            changes = differences(case_before, case_after)
            row["changed_during_suite"] = changes
            if changes["files"] or changes["formal_profile_changed"]:
                row["passed"] = False
                record["abort_reason"] = {"reason": "Frozen inputs or formal profile changed during suite", "suite": name, **changes}
            if row["execution_error"] == "Runner interrupted by user" or (row["cleanup"] and not row["cleanup"]["completed"]):
                record["abort_reason"] = {"reason": "Interruption or incomplete owned-process cleanup", "suite": name}
            write_json(out / name / "result.json", row)
            print(json.dumps({key: row[key] for key in ("suite", "exit_code", "timed_out", "result", "passed")}, ensure_ascii=False), flush=True)
            write_json(out / "summary.json", record)
            if record["abort_reason"]:
                record["not_run"] = names[index + 1:]
                break
        except (OSError, ValueError, KeyboardInterrupt) as error:
            record["abort_reason"] = {"reason": "Hash/evidence operation interrupted or failed", "suite": name, "error": str(error)}
            record["not_run"] = names[index:]
            break
    try:
        after = snapshot(formal)
        write_json(out / "after.json", after)
        record["changed_during_run"] = differences(before, after)
    except (OSError, ValueError) as error:
        record["changed_during_run"] = {"snapshot_error": str(error)}
        record["abort_reason"] = record["abort_reason"] or {"reason": "Final freeze snapshot failed", "error": str(error)}
    record["finished_utc"] = utc_now()
    record["reported_checks"] = sum(row["result"]["checks"] for row in record["suites"] if row["result"] is not None)
    record["reported_failures"] = sum(row["result"]["failures"] for row in record["suites"] if row["result"] is not None)
    record["passed_suites"] = sum(row["passed"] for row in record["suites"])
    change = record["changed_during_run"]
    record["passed"] = (
        record["abort_reason"] is None and len(record["suites"]) == len(names)
        and all(row["passed"] for row in record["suites"])
        and not change.get("files") and not change.get("formal_profile_changed")
        and "snapshot_error" not in change
    )
    write_json(out / "summary.json", record)
    print(json.dumps({"summary": str(out / "summary.json"), "passed": record["passed"], "reported_checks": record["reported_checks"], "reported_failures": record["reported_failures"], "not_run": record["not_run"]}, ensure_ascii=False), flush=True)
    return 0 if record["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
