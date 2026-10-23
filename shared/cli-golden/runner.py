#!/usr/bin/env python3
"""RelayPilot golden-CLI suite runner (cross-platform, stdlib only).

Drives the CLI through shared/cli-golden/cases.json and compares
stdout/stderr/exit code byte-for-byte against golden/<name>.{out,err,exit}
files. Identical argv must produce identical JSON/exit codes on every
platform (docs/CLI-SPEC.md).

Engine-dependent behavior is outside the golden contract: the runner strips
RELAYPILOT_XRAY_BIN from the environment, so `dry-run` takes its documented
"engine not configured" path deterministically on every host. The real
engine path is covered by tests/runtime.rkt under CI's pinned binary.

Dynamic values are normalized in actual output before comparison:
  repository root path      -> {{repo}}
  per-case work directory   -> {{work}}
  release version string    -> {{version}}
  OS errno detail after "system error:" -> {{detail}}

Usage:
  python3 runner.py --binary /path/to/relaypilot-cli.sh [--record]
Without --record the suite verifies; missing golden files are failures,
so CI never silently passes a newly added case.
"""

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

SHARED_DIR = Path(__file__).resolve().parent
REPO = SHARED_DIR.parent.parent

VERSION = re.search(
    r'\(define app-version "([^"]+)"\)',
    (REPO / "app" / "core" / "version.rkt").read_text(encoding="utf-8"),
).group(1)


def normalize(text: str, work_dir: Path) -> str:
    text = text.replace(str(REPO), "{{repo}}")
    text = text.replace(str(work_dir), "{{work}}")
    if VERSION:
        text = text.replace(VERSION, "{{version}}")
    text = re.sub(r"system error: .*", "system error: {{detail}}", text)
    return text


def run_case(binary: str, case: dict, work_dir: Path) -> dict:
    env = {k: v for k, v in os.environ.items() if k != "RELAYPILOT_XRAY_BIN"}
    args = [arg.replace("{{repo}}", str(REPO)).replace("{{work}}", str(work_dir))
            for arg in case["args"]]
    result = subprocess.run([binary] + args, capture_output=True, text=True,
                            encoding="utf-8", errors="replace", timeout=60,
                            cwd=work_dir, env=env)
    return {
        "out": normalize(result.stdout, work_dir),
        "err": normalize(result.stderr, work_dir),
        "exit": str(result.returncode),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="RelayPilot golden-CLI suite")
    parser.add_argument("--binary", required=True,
                        help="Path to the relaypilot CLI launcher")
    parser.add_argument("--record", action="store_true",
                        help="Write actual outputs as golden files instead of verifying")
    parser.add_argument("--cases", default=str(SHARED_DIR / "cases.json"))
    parser.add_argument("--golden-dir", default=str(SHARED_DIR / "golden"))
    args = parser.parse_args()

    cases = json.loads(Path(args.cases).read_text(encoding="utf-8"))["cases"]
    names = [c["name"] for c in cases]
    if len(names) != len(set(names)):
        print("duplicate case names", file=sys.stderr)
        return 1
    golden_dir = Path(args.golden_dir)
    binary = str(Path(args.binary).resolve())

    failures = []
    for case in cases:
        name = case["name"]
        work_dir = Path(tempfile.mkdtemp(prefix=f"relaypilot-golden-{name}-"))
        try:
            actual = run_case(binary, case, work_dir)
        finally:
            shutil.rmtree(work_dir, ignore_errors=True)

        if args.record:
            (golden_dir / f"{name}.out").write_text(actual["out"], encoding="utf-8")
            (golden_dir / f"{name}.err").write_text(actual["err"], encoding="utf-8")
            (golden_dir / f"{name}.exit").write_text(actual["exit"] + "\n", encoding="utf-8")
            print(f"recorded {name}")
            continue

        expected = {}
        missing = []
        for stream, suffix in (("out", ".out"), ("err", ".err"), ("exit", ".exit")):
            path = golden_dir / f"{name}{suffix}"
            if path.exists():
                content = path.read_text(encoding="utf-8")
                expected[stream] = content.rstrip("\n") if stream == "exit" else content
            else:
                missing.append(path.name)
        if missing:
            failures.append(f"{name}: missing golden files: {', '.join(missing)}")
            continue

        mismatches = []
        for stream in ("out", "err", "exit"):
            if actual[stream] != expected[stream]:
                mismatches.append(stream)
        if mismatches:
            failures.append(f"{name}: mismatch in {', '.join(mismatches)}")
            for stream in mismatches:
                print(f"--- {name} {stream} expected ---", file=sys.stderr)
                print(expected[stream], file=sys.stderr)
                print(f"--- {name} {stream} actual ---", file=sys.stderr)
                print(actual[stream], file=sys.stderr)
        else:
            print(f"ok {name}")

    if args.record:
        return 0
    if failures:
        print(f"\n{len(failures)} golden case(s) failed:", file=sys.stderr)
        for failure in failures:
            print(f"  {failure}", file=sys.stderr)
        return 1
    print(f"\n{len(cases)} golden cases verified")
    return 0


if __name__ == "__main__":
    sys.exit(main())
