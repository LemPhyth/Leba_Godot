"""ACT06 reuses the frozen-input/Dummy-audio/isolated-profile regression policy."""
import run_act05_checks
runner=run_act05_checks.runner
runner.ARTIFACT_BASE=runner.PROJECT/"artifacts/leba_act06_20261117"
runner.SUITES+=("act06_combo","act06_waves","act06_crt4_actions","act06_crt4_world","act06_flow")
runner.FROZEN_FILES+=("tools/run_act06_checks.py","tools/import_act06_assets.py","tools/bootstrap_act06_crt3.gd")
runner.FROZEN_FILES+=("tools/import_runtime_assets.py","tools/prepare_act06_crt4.py","tools/convert_act06_crt4.gd","tools/bootstrap_act06_ui.gd","tools/bootstrap_act06_nested_animations.gd","tools/migrate_act06_crt4_inputs.gd","tools/migrate_act06_crt4_jump_hold.gd","tools/migrate_act06_crt4_world.gd","tools/migrate_act06_crt4_nested.gd")
if __name__=="__main__":raise SystemExit(runner.main())
