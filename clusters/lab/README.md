# Lab Cluster

This directory describes the desired state for the Minikube lab cluster.

The lab cluster demonstrates the full workflow:

- Create a Kubernetes cluster with Minikube.
- Install FluxCD.
- Install Traefik, data layer, and observability components.
- Deploy staging through GitOps.
- Run performance validation.
- Promote to the production-like environment through a Git change.

Detailed plans:

- [minikube-system-build-plan.md](minikube-system-build-plan.md)
- [minikube-deployment-runbook.md](minikube-deployment-runbook.md)

GitOps entry point:

```text
clusters/lab/kustomization.yaml
```

Main resources:

```text
namespaces.yaml
sources/
kustomizations.yaml
infrastructure/data/
infrastructure/ingress/
infrastructure/observability/
apps/
```

`kustomizations.yaml` splits reconciliation into phases. Alert rules are applied after kube-prometheus-stack is ready so the `PrometheusRule` CRD already exists.
