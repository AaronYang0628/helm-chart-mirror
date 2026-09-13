#!/usr/bin/env bash
# Consistency checks for mirrored Helm charts.
# FAIL: tgz not in index, index local path missing, catalog.json drift
# WARN (exit 0): charts.yaml version not found on disk
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

WARNINGS=0
FAILURES=0

warn() {
  echo "WARN: $*" >&2
  WARNINGS=$((WARNINGS + 1))
}

fail() {
  echo "FAIL: $*" >&2
  FAILURES=$((FAILURES + 1))
}

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "ERROR: required command not found: $1" >&2
    exit 1
  fi
}

need_cmd python3
need_cmd helm

if ! python3 -c 'import yaml' 2>/dev/null; then
  echo "Installing PyYAML..."
  python3 -m pip install --user pyyaml >/dev/null
fi

INDEX="$ROOT/charts/index.yaml"
CATALOG="$ROOT/assets/catalog.json"

if [[ ! -f "$INDEX" ]]; then
  echo "ERROR: missing $INDEX" >&2
  exit 1
fi

echo "==> Checking tgz ↔ index.yaml and charts.yaml → disk"

mapfile -t CHECK_RESULTS < <(python3 - <<'PY'
import sys
from pathlib import Path
import yaml

root = Path(".").resolve()
charts_dir = root / "charts"
with (charts_dir / "index.yaml").open(encoding="utf-8") as f:
    data = yaml.safe_load(f) or {}

indexed_relpaths = set()
for _name, versions in (data.get("entries") or {}).items():
    for v in versions or []:
        for url in v.get("urls") or []:
            url = str(url).strip()
            if not url or url.startswith(("http://", "https://")):
                continue
            indexed_relpaths.add(url.lstrip("./"))

disk_tgzs = sorted(
    p.relative_to(charts_dir).as_posix() for p in charts_dir.rglob("*.tgz")
)

for rel in disk_tgzs:
    if rel not in indexed_relpaths:
        print(f"TGZ_NOT_IN_INDEX:{rel}")

for rel in sorted(indexed_relpaths):
    if not (charts_dir / rel).is_file():
        print(f"INDEX_PATH_MISSING:{rel}")

charts_yaml = root / "charts.yaml"
if charts_yaml.is_file():
    with charts_yaml.open(encoding="utf-8") as f:
        specs = yaml.safe_load(f) or []
    all_tgz = list(charts_dir.rglob("*.tgz"))
    all_names = {p.name for p in all_tgz}
    for spec in specs:
        if not isinstance(spec, dict):
            continue
        name = str(spec.get("name") or "")
        version = str(spec.get("version") or "")
        if not name or not version:
            continue
        candidates = {
            f"{name}-{version}.tgz",
            f"{name}-{version.lstrip('v')}.tgz",
            f"{name}-v{version.lstrip('v')}.tgz",
        }
        found = bool(candidates & all_names)
        if not found:
            for p in all_tgz:
                stem_ok = p.name.endswith(f"-{version}.tgz") or p.name.endswith(
                    f"-{version.lstrip('v')}.tgz"
                )
                if stem_ok and name in p.name:
                    found = True
                    break
        if not found:
            print(f"CHARTS_YAML_MISSING:{name}:{version}")
PY
)

for line in "${CHECK_RESULTS[@]:-}"; do
  [[ -z "${line:-}" ]] && continue
  case "$line" in
    TGZ_NOT_IN_INDEX:*)
      fail "tgz not referenced in charts/index.yaml: ${line#TGZ_NOT_IN_INDEX:}"
      ;;
    INDEX_PATH_MISSING:*)
      fail "index.yaml local path missing on disk: ${line#INDEX_PATH_MISSING:}"
      ;;
    CHARTS_YAML_MISSING:*)
      rest="${line#CHARTS_YAML_MISSING:}"
      name="${rest%%:*}"
      ver="${rest#*:}"
      warn "charts.yaml entry ${name}@${ver} has no matching tgz under charts/ (historical drift)"
      ;;
    *)
      echo "NOTE: $line"
      ;;
  esac
done

echo "==> Checking assets/catalog.json drift"
TMP_CATALOG="$(mktemp)"
trap 'rm -f "$TMP_CATALOG"' EXIT
python3 scripts/generate-catalog-json.py "$TMP_CATALOG" >/dev/null

if [[ ! -f "$CATALOG" ]]; then
  fail "missing $CATALOG"
elif ! diff -u "$CATALOG" "$TMP_CATALOG" >/tmp/catalog.diff; then
  fail "assets/catalog.json is out of date vs charts/index.yaml (run: python3 scripts/generate-catalog-json.py)"
  echo "---- catalog diff (first 40 lines) ----" >&2
  head -40 /tmp/catalog.diff >&2 || true
else
  echo "catalog.json matches regenerated output"
fi

echo "==> Spot-check: helm show chart (up to 5 recent/largest tgz)"
mapfile -t SPOT < <(
  find charts -name '*.tgz' -printf '%T@ %s %p\n' 2>/dev/null \
    | sort -nr \
    | awk '{print $3}' \
    | head -5
)
if [[ ${#SPOT[@]} -eq 0 ]]; then
  warn "no .tgz files found under charts/ for spot-check"
else
  for tgz in "${SPOT[@]}"; do
    echo "--- helm show chart $tgz"
    if ! out="$(helm show chart "$tgz" 2>&1)"; then
      fail "helm show chart failed: $tgz ($out)"
    else
      echo "$out" | head -8
    fi
  done
fi

echo
echo "Summary: failures=$FAILURES warnings=$WARNINGS"
if [[ "$FAILURES" -gt 0 ]]; then
  exit 1
fi
echo "OK"
exit 0
