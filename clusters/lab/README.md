# Lab Cluster

This directory describes the desired state for the Minikube lab cluster.

The lab cluster demonstrates the full workflow:

- Create a Kubernetes cluster with Minikube.
- Install FluxCD.
- Install ingress, data layer, and observability components.
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
infrastructure/data/
infrastructure/observability/
apps/
```

