"""Read-only full extraction/source audit; writes only artifacts/source_integrity.json."""
from __future__ import annotations

from collections import Counter
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import time

PROJECT = Path(__file__).resolve().parents[1]
WORKSPACE = PROJECT.parent
EXTRACTED = WORKSPACE / "res"
META = EXTRACTED / "_meta"
MANIFEST = META / "asset_manifest.jsonl"
CATALOG = PROJECT / "data/asset_catalog.json"
REPORT = PROJECT / "artifacts/source_integrity.json"


def digest(path: Path) -> str:
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def checked_path(base: Path, relative: str) -> Path:
    candidate = (base / relative).resolve()
    if not candidate.is_relative_to(base.resolve()):
        raise ValueError(f"Path escapes audit root: {relative}")
    return candidate


def check_record(base: Path, row: dict) -> dict:
    result = {"path": row.get("path"), "category": row.get("category", "unspecified")}
    try:
        path = checked_path(base, row["path"])
        before = path.stat()
        actual = digest(path)
        after = path.stat()
        result.update(bytes=after.st_size, sha256=actual)
        if (before.st_size, before.st_mtime_ns) != (after.st_size, after.st_mtime_ns):
            result["error"] = "File changed during hash read"
        elif "bytes" in row and row["bytes"] != after.st_size:
            result["error"] = f"Byte count mismatch: expected {row['bytes']}"
        elif row["sha256"].lower() != actual:
            result["error"] = f"SHA-256 mismatch: expected {row['sha256']}"
    except (OSError, KeyError, ValueError) as error:
        result["error"] = str(error)
    return result


def summarize(rows: list[dict]) -> dict:
    failures = [row for row in rows if "error" in row]
    return {"records": len(rows), "passed": len(rows) - len(failures),
            "bytes_read": sum(row.get("bytes", 0) for row in rows),
            "failures": failures}


def main() -> int:
    started = time.monotonic()
    metadata_paths = [MANIFEST, META / "source_inventory.json", META / "verification.json", CATALOG]
    statuses = sorted(META.glob("*_status.json"))
    metadata_paths += statuses
    metadata_before = {str(path.relative_to(WORKSPACE)): digest(path) for path in metadata_paths}
    inventory = json.loads((META / "source_inventory.json").read_text(encoding="utf-8"))
    original_verification = json.loads((META / "verification.json").read_text(encoding="utf-8"))
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))

    source = inventory["source"]
    source_path = Path(source["path"])
    if not source_path.is_absolute():
        source_path = WORKSPACE / source_path
    if not source_path.resolve().is_relative_to((WORKSPACE / "leba").resolve()):
        raise ValueError("Source inventory points outside the original leba directory")
    source_row = {"path": source_path.relative_to(WORKSPACE).as_posix(),
                  "sha256": source["sha256"], "bytes": source["file_bytes"]}
    source_result = check_record(WORKSPACE, source_row)
    declarations = {"source_inventory": source["sha256"],
                    "extraction_verification": original_verification["source_sha256"],
                    "runtime_catalog": catalog["source_swf"]["sha256"]}
    for path in statuses:
        status = json.loads(path.read_text(encoding="utf-8"))
        if "source_sha256" in status:
            declarations[path.name] = status["source_sha256"]
    declaration_failures = {key: value for key, value in declarations.items()
                            if value != source_result.get("sha256")}

    counts = Counter()
    category_bytes = Counter()
    seen = set()
    failures = []
    total = total_bytes = 0
    with ThreadPoolExecutor(max_workers=4) as executor, MANIFEST.open(encoding="utf-8") as stream:
        batch = []
        for number, line in enumerate(stream, 1):
            try:
                row = json.loads(line)
                normalized = row["path"].replace("\\", "/")
                if normalized in seen:
                    raise ValueError("Duplicate path in extraction manifest")
                seen.add(normalized)
                batch.append(row)
            except (ValueError, KeyError) as error:
                failures.append({"line": number, "error": str(error)})
                continue
            if len(batch) < 1024:
                continue
            for result in executor.map(lambda item: check_record(EXTRACTED, item), batch):
                total += 1
                counts[result["category"]] += 1
                category_bytes[result["category"]] += result.get("bytes", 0)
                total_bytes += result.get("bytes", 0)
                if "error" in result:
                    failures.append(result)
            batch.clear()
            if total % 25600 < 1024:
                print(f"Freshly hashed {total} extraction files", flush=True)
        for result in executor.map(lambda item: check_record(EXTRACTED, item), batch):
            total += 1
            counts[result["category"]] += 1
            category_bytes[result["category"]] += result.get("bytes", 0)
            total_bytes += result.get("bytes", 0)
            if "error" in result:
                failures.append(result)

    # Extra files are reported separately. _meta contains the manifests themselves,
    # so it is intentionally outside the extraction manifest's content scope.
    extra = []
    for directory, folders, files in os.walk(EXTRACTED):
        if Path(directory) == EXTRACTED:
            folders[:] = [name for name in folders if name != "_meta"]
        for name in files:
            relative = (Path(directory) / name).relative_to(EXTRACTED).as_posix()
            if relative not in seen:
                extra.append(relative)

    catalog_sources = summarize([check_record(WORKSPACE, row) for row in catalog["sources"]])
    catalog_outputs = summarize([check_record(PROJECT, row) for row in catalog["outputs"]])
    metadata_after = {str(path.relative_to(WORKSPACE)): digest(path) for path in metadata_paths}
    changed_metadata = [key for key in metadata_before if metadata_before[key] != metadata_after[key]]
    count_matches = total == original_verification["files"]
    bytes_match = total_bytes == original_verification["bytes"]
    passed = (not failures and not extra and not declaration_failures and "error" not in source_result
              and not catalog_sources["failures"] and not catalog_outputs["failures"]
              and not changed_metadata and count_matches and bytes_match)
    report = {
        "schema_version": 1, "verified_at_utc": datetime.now(timezone.utc).isoformat(),
        "passed": passed, "elapsed_seconds": round(time.monotonic() - started, 3),
        "method": "Fresh SHA-256 of every manifest row; no prior hash/cache results reused; read-only input access",
        "source_swf": source_result, "source_hash_declarations": declarations,
        "source_hash_declaration_failures": declaration_failures,
        "extraction_manifest": {"path": MANIFEST.relative_to(WORKSPACE).as_posix(),
                                "records": total, "unique_paths": len(seen), "bytes_read": total_bytes,
                                "category_file_counts": dict(counts), "category_bytes": dict(category_bytes),
                                "matches_original_verification_count": count_matches,
                                "matches_original_verification_bytes": bytes_match, "failures": failures,
                                "unlisted_files_outside_meta": extra},
        "catalog_sources": catalog_sources, "catalog_outputs": catalog_outputs,
        "audit_metadata_hashes": metadata_after, "metadata_changed_during_audit": changed_metadata,
        "scope_limits": ["Checks current content against the existing extraction manifest and source declarations; does not validate SWF runtime behavior.",
                         "Original ZIP, Flash helper programs, unrelated worktrees and metadata not named above are outside this requested audit.",
                         "Godot .import and .godot generated caches are outside catalog output hashes."]}
    REPORT.parent.mkdir(parents=True, exist_ok=True)
    temporary = REPORT.with_suffix(".json.tmp")
    temporary.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    temporary.replace(REPORT)
    print(json.dumps({"passed": passed, "extraction_files": total, "extraction_bytes": total_bytes,
                      "catalog_sources": catalog_sources["records"], "catalog_outputs": catalog_outputs["records"],
                      "elapsed_seconds": report["elapsed_seconds"], "report": str(REPORT)}, ensure_ascii=False))
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
