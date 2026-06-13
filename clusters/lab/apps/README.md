# apps

Cluster entry points for applications managed by FluxCD.

`kustomization.yaml` points to:

```text
apps/dacn/staging
apps/dacn/production
```

Staging is deployed by default. The production-like resource exists, but its `HelmRelease` is `suspend: true` and should only be enabled after staging validation passes.

