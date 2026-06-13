# Infrastructure

Cluster-level platform components live here.

```text
ingress-nginx/
observability/
data/
```

In the Minikube lab, `ingress-nginx` is enabled through the Minikube addon. The data layer and observability components are managed by FluxCD HelmRelease resources.

