# Sub2API chart

This mirror packages the maintained chart from
[`ben-wangz/k8s-at-home`](https://github.com/ben-wangz/k8s-at-home) and pins the
Linux amd64 application image by digest.

## Install

```sh
export CHART_VERSION=0.1.12

helm repo add ay-helm-mirror https://aaronyang0628.github.io/helm-chart-mirror/charts
helm repo update

helm upgrade --install sub2api ay-helm-mirror/sub2api \
  --atomic \
  --version "${CHART_VERSION}" \
  --namespace ai \
  --create-namespace \
  --set ingress.enabled=true \
  --set ingress.hostname=sub2api.example.com \
  --set sub2api.auth.adminPassword="change-me" \
  --set sub2api.auth.jwtSecret="change-me" \
  --set sub2api.auth.totpEncryptionKey="change-me"
```

The same package is published as a public OCI artifact:

```sh
helm upgrade --install sub2api \
  oci://ghcr.io/aaronyang0628/helm-chart-mirror/sub2api \
  --version "${CHART_VERSION}" \
  --namespace ai \
  --create-namespace
```

## Verify

```sh
kubectl -n ai get pods,svc,ingress
```
