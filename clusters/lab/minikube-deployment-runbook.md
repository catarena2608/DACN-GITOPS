# Minikube Deployment Runbook

This runbook describes how to deploy DACN on Minikube to simulate a Kubernetes lab cluster. The goal is to demonstrate the GitOps flow from built image to staging, validation, and production-like promotion.

Automation details are documented in:

```text
docs/automation-guide.md
```

## 1. Assumptions

- The app source repository contains the Helm chart at `deploy/helm/dacn`.
- The GitOps state lives in this repository.
- Images are built and pushed to GHCR by GitHub Actions.
- Minikube is a lab cluster, not real production.
- Secrets in this repository are lab placeholders, not production secrets.

## 2. Create The Minikube Cluster

```bash
minikube start \
  --profile dacn-lab \
  --driver=docker \
  --cpus=8 \
  --memory=14336 \
  --disk-size=80g
```

Enable required addons:

```bash
minikube addons enable metrics-server -p dacn-lab
minikube addons enable ingress -p dacn-lab
minikube addons enable storage-provisioner -p dacn-lab
minikube addons enable default-storageclass -p dacn-lab
kubectl config use-context dacn-lab
```

Check:

```bash
kubectl get nodes
kubectl get pods -A
```

## 3. Configure The App Git Source

File:

```text
clusters/lab/sources/dacn-app-source.yaml
```

Set `spec.url` to the repository that contains the app source and Helm chart:

```yaml
spec:
  url: https://github.com/<owner>/<app-repo>.git
```

FluxCD reads the chart from:

```text
deploy/helm/dacn
```

## 4. Bootstrap FluxCD

```bash
flux bootstrap github \
  --owner=<github-user-or-org> \
  --repository=<gitops-repo> \
  --branch=main \
  --path=clusters/lab \
  --personal
```

After bootstrap, FluxCD reconciles resources from:

```text
clusters/lab/kustomization.yaml
```

Resources include:

```text
namespaces
HelmRepository resources for Bitnami and Prometheus Community
GitRepository pointing to the app repository
MongoDB, Redis, RabbitMQ in namespace data
Prometheus/Grafana and observability components in namespace observability
DACN staging in namespace dacn-staging
DACN production-like in namespace dacn-prod, initially suspended
```

## 5. Deploy The Data Layer

Data layer manifests:

```text
clusters/lab/infrastructure/data/
```

Components:

```text
mongodb   Bitnami MongoDB standalone
redis     Bitnami Redis standalone, auth disabled for lab
rabbitmq  Bitnami RabbitMQ, user dacn
```

Check:

```bash
flux get helmreleases -n data
kubectl -n data get pods
kubectl -n data get svc
```

## 6. Deploy Observability

Observability manifests:

```text
clusters/lab/infrastructure/observability/
```

Check:

```bash
flux get helmreleases -n observability
kubectl -n observability get pods
```

Open Grafana:

```bash
kubectl -n observability port-forward svc/kube-prometheus-stack-grafana 3001:80
```

Lab login:

```text
URL: http://localhost:3001
user: admin
password: dacn-lab-admin
```

Optional UI port-forwards:

```bash
kubectl -n observability port-forward svc/kibana 5601:5601
kubectl -n observability port-forward svc/jaeger-query 16686:16686
```

## 7. Deploy Staging

Staging state:

```text
apps/dacn/staging/
```

Update the image tag in:

```text
apps/dacn/staging/helmrelease.yaml
```

Use an immutable tag from CI:

```yaml
global:
  imageTag: sha-xxxxxxx
```

Commit and push the GitOps change. FluxCD deploys staging.

Check:

```bash
flux get sources git -A
flux get helmreleases -A
kubectl -n dacn-staging get pods
kubectl -n dacn-staging get hpa
kubectl -n dacn-staging get ingress
```

If GHCR images are private, create an image pull secret in `dacn-staging` and `dacn-prod`, then add it to `global.imagePullSecrets`.

## 8. Configure Local Domains

Get the Minikube IP:

```bash
minikube ip -p dacn-lab
```

Add to `/etc/hosts`:

```text
<minikube-ip> staging.dacn.local
<minikube-ip> prod.dacn.local
<minikube-ip> kibana.dacn.local
<minikube-ip> jaeger.dacn.local
```

## 9. Smoke Test Staging

```bash
curl http://staging.dacn.local/
curl http://staging.dacn.local/api/health
curl http://staging.dacn.local/api/auth/health
curl http://staging.dacn.local/api/products/health
curl http://staging.dacn.local/api/order/health
```

If an endpoint fails:

```bash
kubectl -n dacn-staging logs deploy/dacn-staging-gateway
kubectl -n dacn-staging logs deploy/dacn-staging-auth
kubectl -n dacn-staging logs deploy/dacn-staging-product
kubectl -n dacn-staging logs deploy/dacn-staging-order
```

## 10. Load Test And Validation

Run `staging-validation.yml` in the app repository with:

```text
image_tag=sha-xxxxxxx
staging_url=http://staging.dacn.local
run_10k_load_test=false
```

For local Minikube, do not start with 10,000 VUs. Begin with a smaller baseline and increase load gradually. For a real 10,000-VU test, use k6 Cloud or distributed runners.

## 11. Promote Production-Like

Production-like state:

```text
apps/dacn/production/helmrelease.yaml
```

After staging passes, create a GitOps PR that:

1. Changes `spec.suspend` from `true` to `false`.
2. Sets `global.imageTag` to the tag that passed staging.

Example:

```yaml
spec:
  suspend: false
  values:
    global:
      imageTag: sha-xxxxxxx
```

After merge, FluxCD deploys production-like into `dacn-prod`.

Check:

```bash
flux get helmreleases -n dacn-prod
kubectl -n dacn-prod get pods
kubectl -n dacn-prod get ingress
```

## 12. Rollback

Rollback through Git:

```text
revert the promotion commit
or set imageTag back to a known-good sha
```

After pushing, FluxCD reconciles the cluster to the previous desired state.

## 13. Report Artifacts

Include:

- `kubectl get pods -A` screenshot.
- FluxCD successful reconciliation screenshot.
- Staging smoke test screenshot.
- Grafana CPU/memory/HPA dashboard screenshot.
- k6 baseline/load test results.
- Staging and production-like image tag table.
- GitOps rollback explanation.

