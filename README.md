# Helm Chart Mirror

**国内可用的 Helm Chart 镜像** · Faster Helm chart mirror for China.

> **Primary UX:** searchable catalog on GitHub Pages  
> https://aaronyang0628.github.io/helm-chart-mirror/

[中文说明](./README_CN.md) · [Changelog](./CHANGELOG.md)

## Quick start

```shell
helm repo add ay-helm-mirror https://aaronyang0628.github.io/helm-chart-mirror/charts
helm repo update
helm search repo ay-helm-mirror
```

Pull / install a chart (example):

```shell
helm pull ay-helm-mirror/ingress-nginx --version 4.11.3
helm upgrade --install ingress-nginx ay-helm-mirror/ingress-nginx \
  --version 4.11.3 --namespace default --create-namespace
```

Live index: https://aaronyang0628.github.io/helm-chart-mirror/charts/index.yaml

## Catalog page

The Pages homepage loads `charts/index.yaml` in the browser (with `assets/catalog.json` fallback) so chart versions stay in sync when the mirror is updated. Regenerate the JSON snapshot after index changes:

```shell
python3 scripts/generate-catalog-json.py
```


## Automation

- **Weekly mirror sync** (Tue 03:17 UTC, or *workflow_dispatch*): pulls charts listed in `charts.yaml`, rebuilds `charts/index.yaml` + `assets/catalog.json`, and opens a PR on `chore/mirror-sync`. See [scripts/sync-mirror.md](./scripts/sync-mirror.md).
- **Mirror CI**: on PRs/pushes that touch charts or catalog files, `scripts/check-mirror.sh` verifies tgz ↔ index consistency, catalog drift, and spot-checks a few packages with `helm show chart`.
- Sub2API has its own update/publish/CI workflows (unchanged).
  - **sub2api** chart version: `0.1.15` (application `0.2.5`)

## License

See [LICENSE](./LICENSE).
