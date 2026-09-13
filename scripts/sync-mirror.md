# General mirror sync

The **Sync mirrored Helm charts** workflow (`.github/workflows/update-mirror.yaml`)
keeps packages under `charts/` aligned with `charts.yaml`.

## Schedule and manual run

- **Schedule:** weekly, Tuesday 03:17 UTC
- **Manual:** Actions → *Sync mirrored Helm charts* → *Run workflow*

## What it does

1. Runs `ghcr.io/ben-wangz/blog-helm-mirror:main` with `CHART_YAML_FILE` /
   `DESTINATION` pointing at this repo
2. Rebuilds `charts/index.yaml` with Helm (`helm repo index charts`, relative URLs)
3. Refreshes `assets/catalog.json`
4. Opens or updates PR branch `chore/mirror-sync` when there are changes

Pages deploy is **not** done here; the existing Jekyll workflow publishes after
merge to `main`.

## Local consistency check

```shell
bash scripts/check-mirror.sh
```
