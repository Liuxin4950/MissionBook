#!/usr/bin/env python3
"""Validate Flutter package formatting, analyzer diagnostics, and tests.

No auto-fix, destructive action, or unexpected network operation is performed.
Flutter itself may fetch dependencies when --pub-get is requested.
"""

from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser(description="Check Flutter code quality")
    parser.add_argument("--project", type=Path, default=Path.cwd())
    parser.add_argument("--integration", action="store_true")
    parser.add_argument("--pub-get", action="store_true")
    args = parser.parse_args()

    project = args.project.expanduser().resolve()
    if not project.is_dir() or not (project / "pubspec.yaml").is_file():
        print(f"ERROR: Flutter package pubspec.yaml not found in {project}", file=sys.stderr)
        return 2

    flutter = shutil.which("flutter")
    dart = shutil.which("dart")
    if flutter is None or dart is None:
        print("ERROR: Both flutter and dart must be available on PATH", file=sys.stderr)
        return 2

    commands: list[list[str]] = []
    if args.pub_get:
        commands.append([flutter, "pub", "get"])
    commands.extend(
        [
            [dart, "format", "--output=none", "--set-exit-if-changed", "."],
            [flutter, "analyze", "--fatal-infos"],
            [flutter, "test"],
        ]
    )
    if args.integration:
        integration_dir = project / "integration_test"
        if not integration_dir.is_dir() or not any(integration_dir.rglob("*_test.dart")):
            print("ERROR: integration_test/*_test.dart not found", file=sys.stderr)
            return 2
        commands.append([flutter, "test", "integration_test"])

    for command in commands:
        print("RUN:", " ".join(command), flush=True)
        try:
            result = subprocess.run(command, cwd=project, check=False)
        except OSError as exc:
            print(f"ERROR: Cannot launch command: {exc}", file=sys.stderr)
            return 2
        if result.returncode != 0:
            print(f"FAILED: exit code {result.returncode}", file=sys.stderr)
            return result.returncode

    print("PASS: Requested checks finished successfully.")
    if not args.integration:
        print("NOTE: Integration/platform/DB migration checks were not run.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
