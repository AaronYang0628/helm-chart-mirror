# Changelog

## v1.0.0 — 2026-09-13

### Added
- Searchable GitHub Pages catalog (`index.html` + `assets/`) as the primary product UX
- Bilingual UI toggle (中文 / EN): search, family chips, version detail modal, copy-paste Helm commands
- Live load from `./charts/index.yaml` via js-yaml CDN, with `assets/catalog.json` fallback
- `scripts/generate-catalog-json.py` to refresh the JSON snapshot from local `charts/index.yaml`
- Shortened `README.md` and matching `README_CN.md` pointing at the Pages catalog

### Notes
- Does not change `charts/index.yaml` or chart `.tgz` packages
- Repo homepage set to the Pages catalog URL
