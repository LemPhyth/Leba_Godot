"""Sequential isolated ACT02 regressions; preserves prior evidence directories."""
from __future__ import annotations
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
from datetime import datetime, timezone

PROJECT = Path(__file__).resolve().parents[1]

def snapshot():
    return {p.relative_to(PROJECT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
            for folder in ('scripts', 'data', 'tests') for p in (PROJECT/folder).rglob('*')
            if p.is_file() and p.suffix in ('.gd', '.json', '.tscn')}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--name', required=True, help='New artifact subdirectory')
    parser.add_argument('--suites', nargs='*', help='Optional test basenames, without test_/.gd')
    args = parser.parse_args()
    if not re.fullmatch(r'[a-zA-Z0-9_-]+',args.name):raise ValueError('Invalid directory name')
    out = PROJECT/'artifacts/leba_act02_20261115'/args.name
    out.mkdir(parents=True,exist_ok=False)
    exe = PROJECT.parent/'tools/Godot_v4.6.3-stable_mono_win64/Godot_v4.6.3-stable_mono_win64_console.exe'
    names = args.suites or ['actions','m1_actions','hit_timeline','gameplay','services','progression',
        'act02_training','act02_skills','act02_status','act02_v','act02_t','act02_y','act02_y_source','act02_ammo','act02_menu','act02_integration']
    before = snapshot()
    rows = []
    for name in names:
        if not re.fullmatch('[a-zA-Z0-9_]+',name):raise ValueError('Invalid suite')
        case = out/name
        case.mkdir()
        flags = ['--test-mode','--mute-audio']
        if name in ['actions','m1_actions','hit_timeline','act02_training','act02_skills','act02_status','act02_v','act02_t','act02_ammo']:flags += ['--action-lab']
        command = [str(exe),'--headless','--audio-driver','Dummy','--path',str(PROJECT),'--script',f'tests/test_{name}.gd','--',*flags]
        env = os.environ.copy()
        env['LEBA_TEST_ARTIFACT_DIR'] = str(case)
        proc = subprocess.run(command,cwd=PROJECT,env=env,stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=90)
        stdout = proc.stdout.decode('utf8',errors='replace')
        stderr = proc.stderr.decode('utf8',errors='replace')
        (case/'stdout.log').write_text(stdout,encoding='utf8')
        (case/'stderr.log').write_text(stderr,encoding='utf8')
        results = re.findall(r'\w+_RESULT\s+(\{[^\n]+\})',stdout)
        result = json.loads(results[-1]) if results else None
        if result is None:
            progression = re.search(r'Progression: (\d+) passed / (\d+) failed',stdout)
            if progression:result = {'checks':int(progression[1])+int(progression[2]),'failures':int(progression[2])}
        errors = [line for line in (stdout+'\n'+stderr).splitlines() if 'ERROR' in line]
        warnings = [line for line in stderr.splitlines() if 'WARNING' in line]
        row = {'suite':name,'command':command,'exit_code':proc.returncode,'result':result,'errors':errors,'warnings':warnings}
        row['passed'] = proc.returncode == 0 and result is not None and not errors and int(result.get('failures',-1)) == 0
        rows.append(row)
        print(json.dumps({k:row[k] for k in ('suite','exit_code','result','passed')},ensure_ascii=False),flush=True)
    after = snapshot()
    changed = sorted(key for key in before.keys()|after.keys() if before.get(key)!=after.get(key))
    record = {'utc':datetime.now(timezone.utc).isoformat(),'suites':rows,'before_sha256':before,
        'after_sha256':after,'changed_during_run':changed,'passed':all(r['passed'] for r in rows) and not changed,
        'scope':'Actual imported Main/Battle, headless Dummy, isolated fixture saves; no OS keyboard/GPU/native Adobe Flash claim. Original-comparison scope is stated in each suite.'}
    (out/'summary.json').write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    return 0 if record['passed'] else 1

if __name__ == '__main__':raise SystemExit(main())
