# Infrastructure

Cluster-level platform components live here.

```text
ingress-nginx/        optional Minikube ingress notes
observability/
data/
```

The project depends on Kubernetes Ingress, not on a specific Ingress Controller. In a Minikube lab, the ingress addon usually provides NGINX; in another lab, the available controller may be Traefik or another implementation. The data layer and observability components are managed by FluxCD HelmRelease resources.
