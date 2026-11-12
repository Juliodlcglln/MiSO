#!/usr/bin/env python3
"""Valida la sintaxis YAML de la configuración de Calamares y del branding."""

from __future__ import annotations

import sys
from pathlib import Path

try:
    import yaml
except ImportError:  # pragma: no cover
    sys.exit("PyYAML no está instalado: pip install pyyaml")

ROOT = Path(__file__).resolve().parents[1]
TARGETS = [
    ROOT / "installer" / "calamares",
    ROOT / "pjd-shell",
]
errors: list[str] = []

for base in TARGETS:
    if not base.exists():
        continue
    for path in sorted(base.rglob("*")):
        if not path.is_file():
            continue
        if path.suffix not in {".conf", ".desc", ".yaml", ".yml"}:
            continue
        try:
            yaml.safe_load(path.read_text(encoding="utf-8"))
        except Exception as exc:  # noqa: BLE001
            errors.append(f"YAML {path.relative_to(ROOT)}: {exc}")

if errors:
    print("\n".join(errors))
    sys.exit(1)

print("Calamares/PJD YAML OK")
