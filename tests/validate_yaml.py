#!/usr/bin/env python3
"""Valida la sintaxis de los archivos YAML y JSON del proyecto."""

from __future__ import annotations

import json
import sys
from pathlib import Path

try:
    import yaml
except ImportError:  # pragma: no cover
    sys.exit("PyYAML no está instalado: pip install pyyaml")

ROOT = Path(__file__).resolve().parents[1]
errors: list[str] = []

for path in sorted(ROOT.rglob("*.yaml")) + sorted(ROOT.rglob("*.yml")):
    try:
        yaml.safe_load(path.read_text(encoding="utf-8"))
    except Exception as exc:  # noqa: BLE001
        errors.append(f"YAML {path.relative_to(ROOT)}: {exc}")

for path in sorted(ROOT.rglob("*.json")):
    try:
        json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:  # noqa: BLE001
        errors.append(f"JSON {path.relative_to(ROOT)}: {exc}")

if errors:
    print("\n".join(errors))
    sys.exit(1)

print("YAML/JSON OK")
