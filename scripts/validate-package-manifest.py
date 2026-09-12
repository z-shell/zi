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
import re
import sys
from pathlib import Path

SCHEMA_PATH = Path(__file__).resolve().parent.parent / "contracts" / "package-manifest-v1.json"

# Keywords this checker implements. A contract using anything else would be
# silently under-enforced, so an unknown keyword is a hard error rather than a
# quiet pass. That is what stops the contract and this command from drifting.
SUPPORTED = frozenset(
    {
        "$schema", "$id", "$ref", "$defs", "title", "description",
        "type", "required", "properties", "additionalProperties",
        "minLength", "minProperties", "pattern", "const", "items",
        "oneOf", "anyOf", "not",
    }
)
JSON_TYPES: dict[str, type | tuple[type, ...]] = {
    "object": dict, "array": list, "string": str,
    "integer": int, "number": (int, float), "boolean": bool,
}
CONTAINERS = ("properties", "$defs")


def unsupported_keywords(node: object, where: str = "#") -> list[str]:
    """Every contract keyword this checker would otherwise ignore."""
    found: list[str] = []
    if isinstance(node, dict):
        for key, value in node.items():
            named = where.rsplit("/", 1)[-1] in CONTAINERS
            if not named and key not in SUPPORTED:
                found.append(f"{where}/{key}")
            found += unsupported_keywords(value, f"{where}/{key}")
    elif isinstance(node, list):
        for index, value in enumerate(node):
            found += unsupported_keywords(value, f"{where}[{index}]")
    return found


def resolve(node: dict, root: dict) -> dict:
    seen = 0
    while "$ref" in node and seen < 10:
        target: object = root
        for part in node["$ref"].lstrip("#").strip("/").split("/"):
            target = target[part]  # type: ignore[index]
        node = target  # type: ignore[assignment]
        seen += 1
    return node


def validate_against(node: dict, value: object, root: dict, where: str) -> list[str]:
    """Check one value against one contract node."""
    node = resolve(node, root)
    errs: list[str] = []

    expected = node.get("type")
    if expected:
        wanted = JSON_TYPES[expected]
        # JSON separates booleans from numbers; Python does not.
        bad_bool = expected in {"integer", "number"} and isinstance(value, bool)
        if bad_bool or not isinstance(value, wanted):
            shown = "boolean" if isinstance(value, bool) else type(value).__name__
            return [f"{where} is {shown}, expected {expected}"]

    if "const" in node and value != node["const"]:
        errs.append(f"{where} is {value!r}, expected {node['const']!r}")
    if isinstance(value, str):
        if "minLength" in node and len(value) < node["minLength"]:
            errs.append(f"{where} is shorter than {node['minLength']} character(s)")
        if "pattern" in node and not re.search(node["pattern"], value):
            errs.append(f"{where} does not match the contract pattern {node['pattern']}")
    if isinstance(value, dict):
        for name in node.get("required", []):
            if name not in value:
                errs.append(f"{where} is missing {name!r}")
        if "minProperties" in node and len(value) < node["minProperties"]:
            errs.append(f"{where} has fewer than {node['minProperties']} member(s)")
        properties = node.get("properties", {})
        extra = node.get("additionalProperties")
        for key, item in value.items():
            if key in properties:
                errs += validate_against(properties[key], item, root, f"{where}.{key}")
            elif extra is False:
                errs.append(f"{where}.{key} is not part of the contract")
            elif isinstance(extra, dict):
                errs += validate_against(extra, item, root, f"{where}.{key}")
    if isinstance(value, list) and isinstance(node.get("items"), dict):
        for index, item in enumerate(value):
            errs += validate_against(node["items"], item, root, f"{where}[{index}]")
    if "oneOf" in node:
        matched = sum(
            1 for option in node["oneOf"] if not validate_against(option, value, root, where)
        )
        if matched != 1:
            errs.append(f"{where} matched {matched} of the allowed shapes, expected exactly 1")
    if "anyOf" in node and not any(
        not validate_against(option, value, root, where) for option in node["anyOf"]
    ):
        errs.append(f"{where} matched none of the allowed shapes")
    if "not" in node and not validate_against(node["not"], value, root, where):
        errs.append(f"{where} matched a forbidden shape")
    return errs

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
    try:
        doc = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        return [f"{path}: unreadable or invalid JSON: {exc}"]

    try:
        schema = json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        return [f"{SCHEMA_PATH}: contract unreadable: {exc}"]

    ignored = unsupported_keywords(schema)
    if ignored:
        return [
            f"{SCHEMA_PATH}: contract uses keyword(s) this checker does not "
            f"implement, so they cannot be enforced: {', '.join(sorted(ignored))}"
        ]

    # Apply the published contract first, then the rules below, which span
    # `zsh-data` members and so cannot be expressed in JSON Schema.
    errs: list[str] = [
        f"{path}: {message}" for message in validate_against(schema, doc, schema, "manifest")
    ]

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
