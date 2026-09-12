#!/usr/bin/env python3
"""Validate a Zi package manifest against contracts/package-manifest-v1.json.

Checks the structural rules the schema states, plus the rules that span
`zsh-data` members and so cannot be expressed in JSON Schema: a source mode
selects which `plugin-info` identity fields apply, and an identity field that
the declared mode never reads is dead data.

Standard library only, so it runs wherever python3 does.

Usage: validate-package-manifest.py <package.json> [...]
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

# Ice that declares where the package content comes from, and the plugin-info
# fields Zi reads for that mode. See .zi-get-package in lib/zsh/install.zsh.
SOURCE_MODES = {
    "is-snippet": ("url",),
    "git": ("user", "plugin"),
    "from": ("user", "plugin"),
}
READ_BY_ZI = ("user", "plugin", "url", "message", "requires")
ANNEX_CAPABILITIES = ("bgn", "dl", "rdl")


def check(path: Path) -> list[str]:
    errs: list[str] = []
    try:
        doc = json.loads(path.read_text())
    except (OSError, json.JSONDecodeError) as exc:
        return [f"{path}: unreadable or invalid JSON: {exc}"]

    def err(msg: str) -> None:
        errs.append(f"{path}: {msg}")

    if not isinstance(doc, dict):
        return [f"{path}: top level is {type(doc).__name__}, expected an object"]
    if not doc.get("name"):
        err("missing top-level 'name'")

    data = doc.get("zsh-data")
    if not isinstance(data, dict):
        err("missing or non-object 'zsh-data'")
        return errs
    for extra in sorted(set(data) - {"schema", "plugin-info", "zi-ices"}):
        err(f"zsh-data.{extra} is not part of the contract")
    if "schema" in data and data["schema"] != 1:
        err(f"zsh-data.schema is {data['schema']!r}, expected 1")

    info = data.get("plugin-info")
    if not isinstance(info, dict):
        err("missing or non-object 'zsh-data.plugin-info'")
        info = {}
    for key, value in sorted(info.items()):
        if key == "version":
            err("plugin-info.version is never read by Zi; remove it")
        elif key == "required":
            err("plugin-info.required is the legacy spelling; use 'requires'")
        elif key not in READ_BY_ZI:
            err(f"plugin-info.{key} is not read by Zi")
        elif not isinstance(value, str):
            err(f"plugin-info.{key} is {type(value).__name__}, expected string")
    requires = info.get("requires")
    if isinstance(requires, str) and (not requires or ";;" in requires):
        err(f"plugin-info.requires is malformed: {requires!r}")

    ices = data.get("zi-ices")
    if not isinstance(ices, dict):
        err("missing or non-object 'zsh-data.zi-ices'")
        return errs
    if "default" not in ices:
        err(f"no 'default' profile; found {sorted(ices) or 'nothing'}")

    used: set[str] = set()
    for name, profile in sorted(ices.items()):
        if not isinstance(profile, dict):
            err(f"profile {name!r} is {type(profile).__name__}, expected an object")
            continue
        for key, value in sorted(profile.items()):
            if not isinstance(value, str):
                err(
                    f"profile {name!r}: ice {key!r} is {type(value).__name__}; "
                    "ice values are shell strings, quote it"
                )
            if key == "required":
                err(f"profile {name!r}: ice 'required' is the legacy spelling; use 'requires'")
        modes = [m for m in SOURCE_MODES if m in profile]
        if len(modes) != 1:
            err(
                f"profile {name!r} declares {len(modes)} source modes {modes or '[]'}; "
                "exactly one of is-snippet, git or from is required"
            )
            continue
        needed = SOURCE_MODES[modes[0]]
        used.update(needed)
        for field in needed:
            if not info.get(field):
                err(f"profile {name!r} declares {modes[0]!r} but plugin-info has no {field!r}")

    for field in ("user", "plugin", "url"):
        if field in info and field not in used:
            err(f"plugin-info.{field} is set but no profile declares a mode that reads it")
    return errs


def main(argv: list[str]) -> int:
    if not argv:
        print(__doc__, file=sys.stderr)
        return 2
    failed = 0
    for name in argv:
        errs = check(Path(name))
        for e in errs:
            print(e, file=sys.stderr)
        if errs:
            failed += 1
        else:
            print(f"{name}: ok")
    if failed:
        print(f"\n{failed} manifest(s) failed validation", file=sys.stderr)
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
