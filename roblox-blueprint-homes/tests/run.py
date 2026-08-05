#!/usr/bin/env python3
"""Run the Blueprint Homes server-logic suite outside Roblox.

Assembles one Luau chunk from:
    tests/roblox_mock.luau  - Roblox API mock, fake clock, module registry
    src/**/*.luau           - game modules, wrapped as MODULES["Name"]
    tests/spec.luau         - the assertions

Roblox resolves `require` by instance (`require(Shared.Config)`), which plain
Luau cannot do, so each require is rewritten to `req("Config")` against the
harness registry. Sources are otherwise untouched - the tests exercise the
same code that ships.

Usage:  python3 tests/run.py [--luau PATH_TO_LUAU]
"""

from __future__ import annotations

import argparse
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TESTS = ROOT / "tests"

# Modules the suite loads. Client modules are excluded: they need a rendering
# and input surface that a headless mock cannot stand in for honestly.
MODULE_DIRS = ("src/shared", "src/server")
SKIP = {"init.server", "init.client"}

REQUIRE_RE = re.compile(r"require\((?:script\.Parent|script|Shared)\.([A-Za-z_][A-Za-z0-9_]*)\)")
SHARED_LOOKUP_RE = re.compile(r'^(\s*local\s+Shared\s*=\s*).*WaitForChild\("Shared"\).*$', re.M)


def collect_modules() -> list[tuple[str, str]]:
    found: list[tuple[str, str]] = []
    for rel in MODULE_DIRS:
        for path in sorted((ROOT / rel).glob("*.luau")):
            name = path.stem
            if name in SKIP:
                continue
            found.append((name, path.read_text()))
    return found


def rewrite(source: str) -> str:
    # `local Shared = game:GetService(...):WaitForChild("Shared")` has no
    # equivalent here; requires against it are rewritten below, so the handle
    # itself is only a placeholder.
    source = SHARED_LOOKUP_RE.sub(r"\1nil", source)
    return REQUIRE_RE.sub(r'req("\1")', source)


def assemble() -> str:
    parts = [(TESTS / "roblox_mock.luau").read_text()]
    parts.append("\n-- ===== game modules =====\n")
    for name, source in collect_modules():
        parts.append(f'MODULES["{name}"] = function()\n')
        parts.append(rewrite(source))
        parts.append("\nend\n")
    parts.append("\n-- ===== spec =====\n")
    parts.append((TESTS / "spec.luau").read_text())
    return "".join(parts)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--luau", default=shutil.which("luau") or "luau")
    parser.add_argument("--emit", action="store_true", help="write the assembled chunk and exit")
    args = parser.parse_args()

    out = TESTS / ".harness.luau"
    out.write_text(assemble())
    if args.emit:
        print(out)
        return 0

    if not (Path(args.luau).exists() or shutil.which(args.luau)):
        print(f"luau interpreter not found: {args.luau}\nGet one from "
              "https://github.com/luau-lang/luau/releases and pass --luau PATH", file=sys.stderr)
        return 2

    result = subprocess.run([args.luau, str(out)])
    return result.returncode


if __name__ == "__main__":
    raise SystemExit(main())
