#!/usr/bin/env python3
"""Generate assets/catalog.json from charts/index.yaml for Pages fallback."""
from __future__ import annotations

import json
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    print("PyYAML required: pip install pyyaml", file=sys.stderr)
    sys.exit(1)

ROOT = Path(__file__).resolve().parents[1]
INDEX = ROOT / "charts" / "index.yaml"
DEFAULT_OUT = ROOT / "assets" / "catalog.json"
REPO_URL = "https://aaronyang0628.github.io/helm-chart-mirror/charts"


def main(out_path: Path | None = None) -> None:
    OUT = out_path or DEFAULT_OUT
    with INDEX.open(encoding="utf-8") as f:
        data = yaml.safe_load(f)
    entries = data.get("entries") or {}
    catalog = []
    for name, versions in sorted(entries.items()):
        vers = []
        family = None
        for v in versions:
            urls = v.get("urls") or []
            if urls and family is None and "/" in str(urls[0]):
                family = str(urls[0]).split("/")[0]
            vers.append(
                {
                    "version": v.get("version"),
                    "appVersion": v.get("appVersion"),
                    "created": v.get("created"),
                    "urls": urls,
                    "description": v.get("description") or "",
                    "home": v.get("home"),
                    "sources": v.get("sources") or [],
                    "keywords": v.get("keywords") or [],
                    "icon": v.get("icon"),
                }
            )
        latest = vers[0] if vers else {}
        catalog.append(
            {
                "name": name,
                "family": family or "other",
                "description": latest.get("description") or "",
                "keywords": latest.get("keywords") or [],
                "home": latest.get("home"),
                "sources": latest.get("sources") or [],
                "icon": latest.get("icon"),
                "latestVersion": latest.get("version"),
                "appVersion": latest.get("appVersion"),
                "versionCount": len(vers),
                "versions": vers,
            }
        )
    out = {
        "generatedFrom": "charts/index.yaml",
        "repoUrl": REPO_URL,
        "chartCount": len(catalog),
        "charts": catalog,
    }
    OUT.parent.mkdir(parents=True, exist_ok=True)
    with OUT.open("w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=2)
        f.write("\n")
    # verify
    with OUT.open(encoding="utf-8") as f:
        parsed = json.load(f)
    try:
        display = OUT.relative_to(ROOT)
    except ValueError:
        display = OUT
    print(f"Wrote {display} ({parsed['chartCount']} charts)")


if __name__ == "__main__":
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else None
    main(out)
