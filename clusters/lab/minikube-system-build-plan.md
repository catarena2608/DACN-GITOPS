# Minikube Lab System Build Plan

This document describes the plan for building the DACN system on an existing lab server. It does not define whether the server is physical, virtual, or cloud-based; it assumes the server is ready and Minikube is used to create the Kubernetes cluster.

## Goals

The main goal is not only to run the application, but to build a complete enough DevOps workflow:

- Developers push code to the app repository.
- CI builds, tests, and pushes container images.
- The `dacn-gitops` repository stores the desired cluster state.
- FluxCD reconciles staging and production from Git.
- Staging runs reliable validation before production promotion.
- The system exposes metrics, logs, and traces for performance evaluation and failure analysis.
- The lab can simulate high-load scenarios, such as 10,000 users, to analyze system stability.

## Assumptions

- The server is already prepared.
- Docker or a Minikube-compatible container runtime is installed.
- The operator can run `minikube`, `kubectl`, `helm`, `flux`, and `git`.
- Application images are pushed to a container registry such as GHCR or Docker Hub.
- Lab domains can use the hosts file or `minikube tunnel`.
- Real secrets are not stored as plaintext in Git.

## Core Tech Stack

| Group | Technology | Role |
| --- | --- | --- |
| Cluster | Minikube | Kubernetes lab cluster |
| CD/GitOps | FluxCD | Reconcile cluster from Git |
| Package | Helm | Package application and infrastructure |
| Routing | Kubernetes Ingress + available controller | Expose gateway/frontend |
| Data | MongoDB, Redis, RabbitMQ | Database, cache, message broker |
| Metrics | Prometheus, Grafana | Collect and visualize metrics |
| Logs | OpenTelemetry Collector, Elasticsearch, Kibana | Collect, store, search, and analyze logs |
| Traces | OpenTelemetry Collector, Elasticsearch, Jaeger UI | Store and visualize request traces |
| Load test | k6 | Validate load and quality thresholds |

## Recommended Resources

Because ELK, Prometheus, Jaeger, MongoDB, Redis, RabbitMQ, and multiple services can run together in the same lab cluster, recommended resources are:

| Resource | Recommendation |
| --- | --- |
| CPU | 8 vCPU |
| RAM | 14-16 GB |
| Disk | 80 GB |
| Kubernetes node | 1 Minikube node |

If the machine is weaker, deploy by phase and enable Elasticsearch/Kibana only when log analysis is needed.

## Create The Minikube Cluster

```bash
minikube start \
  --profile dacn-lab \
  --driver=docker \
  --cpus=8 \
  --memory=14336 \
  --disk-size=80g \
  --kubernetes-version=stable
```

```bash
kubectl config use-context dacn-lab
minikube addons enable metrics-server -p dacn-lab
minikube addons enable ingress -p dacn-lab
minikube addons enable storage-provisioner -p dacn-lab
minikube addons enable default-storageclass -p dacn-lab
```

## Expected Namespaces

```text
flux-system
ingress-nginx or controller-specific namespace
observability
data
dacn-staging
dacn-prod
```

Meaning:

- `flux-system`: FluxCD controllers.
- `ingress-nginx` or controller-specific namespace: Ingress controller.
- `observability`: Prometheus, Grafana, Elasticsearch, Kibana, OTel Collector, Jaeger.
- `data`: MongoDB, Redis, RabbitMQ.
- `dacn-staging`: staging environment.
- `dacn-prod`: production-like environment.

## Bootstrap FluxCD

After creating the `dacn-gitops` repository on GitHub:

```bash
flux bootstrap github \
  --owner=<github-user-or-org> \
  --repository=dacn-gitops \
  --branch=main \
  --path=clusters/lab \
  --personal
```

After bootstrap, FluxCD reads `clusters/lab` and reconciles the Kustomization/manifests defined in Git.

## Desired GitOps Layout

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
│       └── infrastructure/
│           ├── data/
│           ├── ingress-nginx/
│           └── observability/
└── secrets/
    ├── staging/
    └── production/
```

Organization principles:

- `clusters/lab`: entry point read by FluxCD.
- `infrastructure`: cluster platform components.
- `apps`: cluster-level application entry point.
- `apps/dacn/base`: shared application configuration.
- `apps/dacn/staging`: staging configuration.
- `apps/dacn/production`: production-like configuration.
- `secrets`: templates or encrypted secrets only.

## Phase 1: Minimal Platform

Goal: create a working cluster and GitOps loop.

Deploy:

- Minikube cluster.
- Ingress Controller.
- FluxCD.
- Standard namespaces.
- Default StorageClass.
- Metrics Server.

Check:

```bash
kubectl get nodes
kubectl get pods -A
flux check
```

Definition of Done:

- Cluster is healthy.
- FluxCD reconciles the repository.
- Ingress controller is stable.

## Phase 2: Data Layer

Goal: provide runtime dependencies for microservices.

Deploy:

- MongoDB for services that need a database.
- Redis for cache/token/session data.
- RabbitMQ for messaging.

Lab recommendations:

- Use existing Helm charts such as Bitnami.
- Keep replica counts low to save resources.
- Use persistent volumes with short retention.
- Do not over-model database HA if the project focus is workflow and performance validation.

Definition of Done:

- Services in `dacn-staging` can connect to MongoDB, Redis, and RabbitMQ.
- Secret/config references are explicit.
- Connection strings are not hard-coded in source code.

## Phase 3: Metrics

Goal: understand system health through metrics.

Deploy:

- Prometheus.
- Grafana.
- Node Exporter.
- kube-state-metrics.
- ServiceMonitor or PodMonitor where supported.

Metrics to observe:

- CPU, memory, network, disk.
- Pod restart count.
- Request rate.
- Error rate.
- p95/p99 latency.
- MongoDB/Redis/RabbitMQ health.

Definition of Done:

- Grafana can show cluster dashboards.
- Prometheus scrapes important workloads.
- Baseline metrics exist before load tests.

## Phase 4: Logs With Elasticsearch And Kibana

Goal: investigate failures with searchable logs.

Elasticsearch/Kibana is heavier than Loki, but is reasonable for this project when the goal is deeper log analysis:

- Elasticsearch supports full-text search, filtering, aggregation, and structured log analytics.
- Kibana supports query, dashboards, and drill-down analysis.
- In distributed microservices failures, searching by `trace_id`, `user_id`, `request_id`, status code, or service name is valuable.
- ELK supports an enterprise-style operations story: logs are used not only to read errors, but to analyze incidents, system behavior, and error trends.

If asked why ELK is heavy:

- Yes, ELK is heavier than Loki, so production needs separate sizing.
- In the lab, Elasticsearch is not deployed as production HA.
- Use single-node Elasticsearch, short retention, and explicit resource limits.
- Keep only logs needed for testing and analysis.
- The academic purpose is to prove log analytics and incident analysis, not to minimize infrastructure cost.

Lab implementation:

- Elasticsearch single-node.
- Kibana one replica.
- OpenTelemetry Collector receives application logs and writes them to Elasticsearch.
- Applications should emit structured logs and include `trace_id`/`request_id` where possible.

Definition of Done:

- Kibana can query logs by service.
- Errors can be searched by status code or keyword.
- Logs include timestamp, service name, environment, and request identifier.

## Phase 5: Tracing

Goal: see how a request moves through the gateway and microservices.

Deploy:

- OpenTelemetry Collector.
- Elasticsearch as trace storage.
- Jaeger UI for trace visualization.
- Application instrumentation where supported.

Trace evidence should show:

- Request entering API Gateway.
- Gateway calling Auth/Product/Order.
- Services calling database/cache/message broker.
- Latency per span.

Definition of Done:

- Jaeger UI shows traces and spans.
- The team can identify which service contributes most to latency during load tests.

## Phase 6: Deploy DACN Staging

Goal: deploy the application to staging with FluxCD.

Suggested flow:

1. CI in the app repository builds the image.
2. CI pushes an immutable tag, for example `sha-a1b2c3d`.
3. Update the image tag in `dacn-gitops/apps/dacn/staging`.
4. FluxCD reconciles staging.
5. Run smoke and load tests against staging.

Staging ingress:

```text
staging.dacn.local
```

If using the hosts file:

```bash
minikube ip -p dacn-lab
```

Map the IP:

```text
<minikube-ip> staging.dacn.local
<minikube-ip> prod.dacn.local
```

Definition of Done:

- Frontend/gateway is reachable through ingress.
- Services are healthy.
- Staging uses separate secrets/config.
- Smoke tests pass.

## Phase 7: Staging Validation

This is the main quality phase of the project.

Validation should include:

- Smoke test for main endpoints.
- Integration tests for important business flows.
- Contract tests if service communication is complex.
- k6 load tests.
- Metrics/log/trace checks during the test.

The 10,000-user scenario must be defined clearly. It can mean:

- 10,000 concurrent virtual users, or
- 10,000 registered users in the test dataset, or
- 10,000 sessions/users over a time window.

For this project, present it as:

- k6 gradually ramps to 10,000 virtual users if resources allow.
- If the lab cannot reach absolute 10,000 VUs, use smaller empirical results to estimate limits, bottlenecks, and capacity planning.

Reference thresholds:

| Metric | Target |
| --- | --- |
| Error rate | < 1% |
| p95 latency | < 800 ms |
| p99 latency | < 1500 ms |
| Pod crash/restart | No abnormal increase |
| CPU/memory | No prolonged limit pressure |

Definition of Done:

- k6 result report exists.
- Metrics screenshots/dashboards exist.
- Logs/traces demonstrate root-cause analysis when errors or high latency occur.
- Bottleneck conclusion and improvement recommendations exist.

## Phase 8: Promote Production-Like

Goal: prove the process of promoting a validated release.

Suggested flow:

1. Staging validation passes.
2. Create a pull request in `dacn-gitops`.
3. Copy the validated image tag from staging to production.
4. Review the change.
5. Merge to `main`.
6. FluxCD reconciles `dacn-prod`.
7. Observe metrics/logs/traces after deployment.

Do not use GitHub Actions to run `kubectl apply` or `helm upgrade` directly.

Definition of Done:

- Production-like runs the same image that passed staging.
- Promotion history exists in Git.
- Rollback is possible by reverting the image tag commit.

## Implementation Priority

1. Minikube + kubectl + ingress.
2. FluxCD bootstrap.
3. Namespace and GitOps skeleton.
4. Minimal data layer.
5. Deploy DACN staging.
6. Smoke test staging.
7. Prometheus + Grafana.
8. Basic k6 load test.
9. Elasticsearch/Kibana logging.
10. OTel + Jaeger tracing.
11. 10,000-user load test or equivalent capacity test.
12. Production-like promotion.

This order prevents the project from becoming too heavy at the beginning. Build the core workflow first, then deepen observability and performance analysis.

## System-Wide Definition Of Done

The lab is complete when:

- Minikube cluster is stable.
- FluxCD reconciles the full desired state.
- Staging and production-like use separate namespaces/config.
- Application is reachable through ingress.
- Database/cache/message broker works.
- Metrics are visible in Grafana.
- Logs are searchable in Kibana.
- Traces are visible in Jaeger UI.
- Staging validation report exists.
- Load test results and bottleneck analysis exist.
- Promotion/rollback works through GitOps.

## Report Limitations

The Minikube lab is not real production. Do not claim the system is ready for enterprise production scale.

More accurate statements:

- The lab proves the DevOps workflow from code to production-like.
- The lab proves quality validation before release.
- The lab demonstrates observability through metrics, logs, and traces.
- Load tests help identify bottlenecks and estimate capacity.
- Real production still needs HA, backup, disaster recovery, autoscaling, security hardening, and dedicated infrastructure sizing.
