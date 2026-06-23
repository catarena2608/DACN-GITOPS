# dacn-gitops

GitOps repository for the DACN project.

This repository describes only the **desired cluster state**: namespaces, ingress, data layer, observability, secret references, HelmRelease/Kustomization resources, and environment-specific deployment configuration.

Application source code, Dockerfiles, the base Helm chart, test scripts, and technical documentation live in the app repository.

## Goals

- Use FluxCD as the CD controller.
- Use Git as the source of truth for cluster state.
- Keep `staging` and `production` configuration clearly separated.
- Do not commit real secrets to GitHub.
- Support a Minikube lab while keeping a production-like operating model.

## Current Structure

```text
dacn-gitops/
├── apps/
│   └── dacn/
│       ├── base/
│       ├── staging/
│       └── production/
├── clusters/
│   └── lab/
│       ├── apps/
│       ├── flux-system/
│       ├── infrastructure/
│       │   ├── data/
│       │   ├── ingress-nginx/        # optional Minikube ingress notes
│       │   └── observability/
│       ├── sources/
│       ├── kustomization.yaml
│       ├── namespaces.yaml
│       └── minikube-system-build-plan.md
├── docs/
│   └── automation-guide.md
├── scripts/
│   ├── bootstrap-minikube.sh
│   ├── promote-production.sh
│   ├── set-image-tag.sh
│   ├── smoke-test.sh
│   └── validate-gitops.sh
└── secrets/
    ├── production/
    └── staging/
```

The project depends on Kubernetes Ingress, not on a specific controller. In the current lab, `ingressClassName` selects the available controller for that cluster.

## Lab Deployment Plan

Main documentation:

- [clusters/lab/minikube-system-build-plan.md](clusters/lab/minikube-system-build-plan.md)
- [clusters/lab/minikube-deployment-runbook.md](clusters/lab/minikube-deployment-runbook.md)
- [docs/automation-guide.md](docs/automation-guide.md)

## Automation Scripts

Operational Minikube/GitOps scripts live in:

```text
scripts/
```

The CI flow that updates the staging image tag is described in:

```text
docs/automation-guide.md
```

## Principles

- GitHub Actions builds, tests, and pushes images in the app repository.
- FluxCD reads this repository and reconciles the cluster.
- Staging and production should use immutable image tags such as `sha-<commit>`, not `latest`.
- Real secrets should be managed with External Secrets, Sealed Secrets, or SOPS. The `secrets/` directory should contain templates or encrypted manifests only.
- Production changes should go through pull requests so the promotion history remains auditable.
