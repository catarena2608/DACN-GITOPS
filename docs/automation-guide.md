# Automation Guide

This document explains how to automate DACN deployment on the Minikube lab with GitHub Actions and FluxCD.

## 1. Automation Goal

Target flow:

```text
Developer pushes code to the app repository
-> GitHub Actions build/test/security/smoke
-> build and push GHCR images tagged sha-xxxxxxx
-> GitHub Actions updates the staging imageTag in dacn-gitops
-> FluxCD reconciles staging on Minikube
-> smoke/load validation runs
-> if validation passes, promote the same image tag to production-like
```

GitHub Actions does not run `kubectl apply` against the cluster. Actions only updates Git. FluxCD is the only component that reconciles the cluster from Git state.

## 2. Existing Scripts

In the `dacn-gitops` repository:

```text
scripts/bootstrap-minikube.sh
scripts/validate-gitops.sh
scripts/set-image-tag.sh
scripts/promote-production.sh
scripts/smoke-test.sh
```

In the app repository:

```text
scripts/update-gitops-staging.sh
```

`update-gitops-staging.sh` is used by `ci-main.yml` to update `apps/dacn/staging/helmrelease.yaml` in the GitOps repository.

## 3. GitHub Secrets And Variables

In the app repository, configure:

```text
Settings -> Secrets and variables -> Actions
```

Required secrets:

```text
GITOPS_TOKEN
AUTH_ENV_DEV
PRODUCT_ENV_DEV
ORDER_ENV_DEV
GATEWAY_ENV_DEV
```

`GITOPS_TOKEN` should be a fine-grained personal access token with:

```text
Repository: dacn-gitops
Permission: Contents read/write
```

Recommended variable:

```text
GITOPS_REPOSITORY=<owner>/dacn-gitops
```

If `GITOPS_REPOSITORY` is not set, the workflow defaults to:

```text
<github.repository_owner>/dacn-gitops
```

## 4. Bootstrap Minikube And FluxCD

Run from the `dacn-gitops` directory:

```bash
GITHUB_OWNER="<github-user-or-org>" \
GITOPS_REPOSITORY="dacn-gitops" \
scripts/bootstrap-minikube.sh
```

The script:

```text
starts Minikube profile dacn-lab
enables metrics-server
enables ingress
enables storage-provisioner
enables default-storageclass
runs flux bootstrap github --path clusters/lab
```

To create Minikube without bootstrapping Flux:

```bash
SKIP_FLUX_BOOTSTRAP=true scripts/bootstrap-minikube.sh
```

## 5. Validate GitOps Locally

Render Kustomize:

```bash
scripts/validate-gitops.sh
```

Check cluster and Flux state:

```bash
CHECK_CLUSTER=true scripts/validate-gitops.sh
```

This is equivalent to checking:

```text
kubectl kustomize clusters/lab
flux check
flux get sources
flux get helmreleases
kubectl get pods -A
```

## 6. CI Updates Staging Automatically

Workflow `ci-main.yml` contains:

```text
update-gitops-staging
```

The job runs only on push to `main`.

After all images are pushed to GHCR, the job:

```text
computes image tag sha-xxxxxxx
checks out the app repository
checks out dacn-gitops with GITOPS_TOKEN
runs scripts/update-gitops-staging.sh
commits the new imageTag into dacn-gitops
pushes to main of dacn-gitops
```

FluxCD running in Minikube detects the commit and deploys staging.

## 7. Set Image Tag Manually

Update staging:

```bash
scripts/set-image-tag.sh staging sha-xxxxxxx
```

Update production-like:

```bash
scripts/set-image-tag.sh production sha-xxxxxxx
```

After changing the file, commit and push the GitOps repository so FluxCD can reconcile.

## 8. Smoke Test Staging

After staging deploys:

```bash
scripts/smoke-test.sh http://staging.dacn.local
```

Production-like:

```bash
scripts/smoke-test.sh http://prod.dacn.local
```

## 9. Promote Production-Like

After staging validation passes:

```bash
scripts/promote-production.sh
```

The script:

```text
reads the current staging imageTag
writes that imageTag to production
changes production HelmRelease from suspend: true to suspend: false
```

Specify a tag explicitly:

```bash
scripts/promote-production.sh sha-xxxxxxx
```

Commit or open a PR with the change. Once merged, FluxCD deploys production-like.

## 10. Rollback

Rollback through Git:

```text
revert the imageTag update commit
or set imageTag back to a known-good sha
```

Example:

```bash
scripts/set-image-tag.sh staging sha-oldgood
```

After pushing, FluxCD reconciles the cluster back to the desired state.

## 11. Current Limitations

```text
Staging validation can still be run manually with staging-validation.yml.
Production-like promotion should go through PR review.
Secrets in this repository are lab placeholders, not SOPS/Sealed Secrets yet.
OpenTelemetry instrumentation in the application is still required for real traces.
If GHCR packages are private, create imagePullSecrets in dacn-staging and dacn-prod.
```

