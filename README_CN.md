# Helm Chart 镜像

**国内可用的 Helm Chart 镜像** · 加速 Chart 下载与安装。

> **主入口：** GitHub Pages 可搜索目录  
> https://aaronyang0628.github.io/helm-chart-mirror/

[English](./README.md) · [更新日志](./CHANGELOG.md)

## 快速开始

```shell
helm repo add ay-helm-mirror https://aaronyang0628.github.io/helm-chart-mirror/charts
helm repo update
helm search repo ay-helm-mirror
```

拉取 / 安装示例：

```shell
helm pull ay-helm-mirror/ingress-nginx --version 4.11.3
helm upgrade --install ingress-nginx ay-helm-mirror/ingress-nginx \
  --version 4.11.3 --namespace default --create-namespace
```

在线索引：https://aaronyang0628.github.io/helm-chart-mirror/charts/index.yaml

## 目录页说明

Pages 首页在浏览器中拉取 `charts/index.yaml`（失败时回退到 `assets/catalog.json`），镜像更新后版本自动同步。索引变更后可重新生成 JSON 快照：

```shell
python3 scripts/generate-catalog-json.py
```

## 许可

见 [LICENSE](./LICENSE)。
