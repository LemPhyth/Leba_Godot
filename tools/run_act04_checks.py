"""ACT04 frozen-input regression; reuse the verified ACT03 runner and policies.

No asset imports, author migrations or repairs run during verification. Every
suite gets Dummy audio and an isolated profile. GPU/native checks are separate.
"""
import run_act03_checks as runner

runner.ARTIFACT_BASE = runner.PROJECT / "artifacts/leba_act04_20261117"
runner.SUITES += ("act04_crt1", "act04_crt2", "act04_flow", "act04_cutin")
runner.FROZEN_FILES += ("tools/run_act04_checks.py",)

if __name__ == "__main__":
    raise SystemExit(runner.main())
