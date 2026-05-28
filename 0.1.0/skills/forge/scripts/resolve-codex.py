#!/usr/bin/env python3
"""Forge helper: resolve the newest codex-companion.mjs and pre-flight Codex.

Replaces brittle inline globbing + JSON-by-grep in the skill body.

Contract:
    stdout = absolute path to codex-companion.mjs   exit 0  -> usable
    stdout = "UNAVAILABLE"                           exit 1  -> degrade to
                                                                the superpowers
                                                                reviewer

"Unavailable" covers: codex plugin not installed, no script found, node or
Codex CLI missing, or Codex not authenticated. Conservative by design — a
false UNAVAILABLE only costs a safe fallback, never a wrong review.
"""

import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

HOME = Path.home()
GLOBS = (
    ".claude/plugins/cache/*/codex/*/scripts/codex-companion.mjs",
    ".claude/plugins/marketplaces/*/plugins/codex/scripts/codex-companion.mjs",
)
SETUP_TIMEOUT_S = 30


def unavailable():
    print("UNAVAILABLE")
    sys.exit(1)


def version_key(path: Path) -> tuple:
    """Natural-sort key so 1.10 > 1.9; non-numeric segments compare as text."""
    return tuple(
        (1, int(tok)) if tok.isdigit() else (0, tok)
        for tok in re.split(r"(\d+)", str(path))
    )


def newest_companion() -> "Path | None":
    found = [p for g in GLOBS for p in HOME.glob(g) if p.is_file()]
    return max(found, key=version_key) if found else None


def codex_ready(script: Path) -> bool:
    """True iff `setup --json` reports node + Codex + authenticated."""
    try:
        proc = subprocess.run(
            ["node", str(script), "setup", "--json"],
            capture_output=True,
            text=True,
            timeout=SETUP_TIMEOUT_S,
        )
    except (subprocess.TimeoutExpired, OSError):
        return False
    if proc.returncode != 0:
        return False
    try:
        data = json.loads(proc.stdout)
    except (json.JSONDecodeError, ValueError):
        return False

    codex = data.get("codex") or {}
    auth = data.get("auth") or {}
    return bool(data.get("ready") and codex.get("available") and auth.get("loggedIn"))


def main() -> None:
    if shutil.which("node") is None:
        unavailable()
    script = newest_companion()
    if script is None or not codex_ready(script):
        unavailable()
    print(script)


if __name__ == "__main__":
    main()
