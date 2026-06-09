# apps

Cluster entry points for applications managed by FluxCD.

File `kustomization.yaml` trỏ tới:

```text
apps/dacn/staging
apps/dacn/production
```

Staging được deploy mặc định. Production-like đã có resource nhưng `HelmRelease` đang `suspend: true` để chỉ bật sau khi staging validation pass.
