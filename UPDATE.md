### Update Index file
after you add some chart in dir `charts`, you need to update `index.yaml`
```shell
helm repo index charts
```

### Update Sub2API

The `Update Sub2API chart` workflow checks for a new stable release daily and
opens a pull request. To run the same process locally:

```shell
bash scripts/sub2api.sh update
bash scripts/sub2api.sh verify
```

After the pull request is merged, `Publish Sub2API chart` publishes the package
to `oci://ghcr.io/aaronyang0628/helm-chart-mirror/sub2api`. The GHCR package must
remain public so anonymous pulls can be verified.
