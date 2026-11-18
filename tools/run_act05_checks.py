"""ACT05 regression using the established frozen-input, isolated-profile runner."""
import run_act04_checks
runner=run_act04_checks.runner
runner.ARTIFACT_BASE=runner.PROJECT/"artifacts/leba_act05_20261117"
runner.SUITES+=("act05_crt3_actions","act05_crt3_special","act05_flow","act05_feedback")
runner.FROZEN_FILES+=("tools/run_act05_checks.py","tools/prepare_act05_rules.py","tools/convert_act05_crt3.gd","tools/bootstrap_act05_ui.gd","tools/render_act05_filtered.py")
if __name__=="__main__":raise SystemExit(runner.main())
