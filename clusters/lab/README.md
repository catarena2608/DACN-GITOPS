# Lab Cluster

Thư mục này mô tả trạng thái mong muốn của cluster lab chạy bằng Minikube.

Cluster lab dùng để chứng minh toàn bộ workflow:

- Tạo Kubernetes cluster bằng Minikube.
- Cài FluxCD.
- Cài ingress, data layer và observability.
- Deploy staging bằng GitOps.
- Chạy kiểm thử hiệu năng.
- Promote sang production-like environment bằng thay đổi Git.

Plan chi tiết:

- [minikube-system-build-plan.md](minikube-system-build-plan.md)
- [minikube-deployment-runbook.md](minikube-deployment-runbook.md)

Entrypoint GitOps:

```text
clusters/lab/kustomization.yaml
```

Resource chính hiện có:

```text
namespaces.yaml
sources/
infrastructure/data/
infrastructure/observability/
apps/
```
