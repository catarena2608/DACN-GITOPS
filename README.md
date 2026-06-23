# dacn-gitops

GitOps repository for the DACN project.

This repository describes only the **desired cluster state**: namespaces, ingress, data layer, observability, secret references, HelmRelease/Kustomization resources, and environment-specific deployment configuration.

Production promotion belongs to the CD/GitOps flow. The administrator runs `scripts/promote-production.sh` locally, reviews the Git diff, then commits and pushes the GitOps change. FluxCD performs the actual Kubernetes reconciliation after the GitOps repository is updated.

```bash
scripts/promote-production.sh
git diff apps/dacn/production/helmrelease.yaml
git add apps/dacn/production/helmrelease.yaml
git commit -m "chore: promote staging image to production"
git push
```

By default, the script uses the newest quality gate summary from `../DACN/reports/production-gate`. To use a specific summary:

```bash
scripts/promote-production.sh --gate-summary ../DACN/reports/production-gate/<run-id>/production-readiness-summary.md
```

To promote a specific immutable tag instead of the current staging tag:

```bash
scripts/promote-production.sh sha-abc1234
```

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
│       │   ├── ingress/
│       │   └── observability/
│       ├── sources/
│       ├── kustomizations.yaml
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

The lab cluster installs Traefik through FluxCD and uses the `traefik` IngressClass for application and observability ingress resources.

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
