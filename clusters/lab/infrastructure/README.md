# Infrastructure

Cluster-level platform components live here.

```text
ingress/
observability/
data/
```

Traefik is managed by FluxCD as the lab Ingress Controller. The data layer and observability components are also managed by FluxCD HelmRelease resources.
