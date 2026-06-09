# Minikube Deployment Runbook

Runbook này mô tả kịch bản triển khai hệ thống DACN trên Minikube để mô phỏng một Kubernetes cluster. Mục tiêu là chứng minh luồng GitOps từ image đã build tới staging, validation, rồi promote sang production-like namespace.

## 1. Giả Định Ban Đầu

- Source app nằm trong repo `dacn-app` hoặc `My_DACN`.
- GitOps state nằm trong repo `dacn-gitops`.
- Image được build và push lên GHCR bởi GitHub Actions.
- Minikube chỉ là lab cluster, chưa đại diện cho production thật.
- Secret trong repo này là placeholder cho lab, không phải secret production.

## 2. Tạo Minikube Cluster

```bash
minikube start \
  --profile dacn-lab \
  --driver=docker \
  --cpus=8 \
  --memory=14336 \
  --disk-size=80g
```

Bật các addon cần thiết:

```bash
minikube addons enable metrics-server -p dacn-lab
minikube addons enable ingress -p dacn-lab
minikube addons enable storage-provisioner -p dacn-lab
minikube addons enable default-storageclass -p dacn-lab
kubectl config use-context dacn-lab
```

Kiểm tra:

```bash
kubectl get nodes
kubectl get pods -A
```

## 3. Cấu Hình Git Source Cho App

File cần sửa:

```text
clusters/lab/sources/dacn-app-source.yaml
```

Mặc định resource đang trỏ tới:

```text
https://github.com/catarena2608/dacn-app.git
```

Nếu repo app trên GitHub có tên khác, đổi trường `spec.url` về đúng repository đang chứa source code và Helm chart:

```yaml
spec:
  url: https://github.com/<owner>/<app-repo>.git
```

FluxCD sẽ đọc chart tại:

```text
deploy/helm/dacn
```

## 4. Bootstrap FluxCD

Chạy bootstrap với repo GitOps:

```bash
flux bootstrap github \
  --owner=<github-user-or-org> \
  --repository=dacn-gitops \
  --branch=main \
  --path=clusters/lab \
  --personal
```

Sau bootstrap, FluxCD sẽ reconcile các resource trong:

```text
clusters/lab/kustomization.yaml
```

Resource được tạo gồm:

```text
namespaces
HelmRepository cho Bitnami và Prometheus Community
GitRepository trỏ tới repo app
MongoDB, Redis, RabbitMQ trong namespace data
Prometheus/Grafana trong namespace observability
DACN staging trong namespace dacn-staging
DACN production-like đang suspend trong namespace dacn-prod
```

## 5. Triển Khai Data Layer

Data layer được khai báo tại:

```text
clusters/lab/infrastructure/data/
```

Thành phần:

```text
mongodb   Bitnami MongoDB standalone
redis     Bitnami Redis standalone, auth disabled cho lab
rabbitmq  Bitnami RabbitMQ, user dacn
```

Kiểm tra:

```bash
flux get helmreleases -n data
kubectl -n data get pods
kubectl -n data get svc
```

## 6. Triển Khai Observability Cơ Bản

Observability hiện bật trước Prometheus và Grafana:

```text
clusters/lab/infrastructure/observability/prometheus-stack.yaml
```

Kiểm tra:

```bash
flux get helmreleases -n observability
kubectl -n observability get pods
```

Mở Grafana bằng port-forward:

```bash
kubectl -n observability port-forward svc/kube-prometheus-stack-grafana 3001:80
```

Thông tin lab:

```text
URL: http://localhost:3001
user: admin
password: dacn-lab-admin
```

ELK, OpenTelemetry và Jaeger sẽ là phase sau nếu máy Minikube đủ tài nguyên.

## 7. Triển Khai Staging

Staging nằm tại:

```text
apps/dacn/staging/
```

Cần cập nhật image tag trong:

```text
apps/dacn/staging/helmrelease.yaml
```

Đổi:

```yaml
global:
  imageTag: latest
```

Thành tag bất biến đã được CI push lên GHCR:

```yaml
global:
  imageTag: sha-xxxxxxx
```

Sau khi commit và push vào repo GitOps, FluxCD sẽ deploy staging.

Kiểm tra:

```bash
flux get sources git -A
flux get helmreleases -A
kubectl -n dacn-staging get pods
kubectl -n dacn-staging get hpa
kubectl -n dacn-staging get ingress
```

Nếu GHCR image là private, tạo image pull secret trong `dacn-staging` và `dacn-prod`, rồi thêm tên secret vào `global.imagePullSecrets`.

## 8. Cấu Hình Domain Local

Lấy IP Minikube:

```bash
minikube ip -p dacn-lab
```

Thêm vào hosts file của máy:

```text
<minikube-ip> staging.dacn.local
<minikube-ip> prod.dacn.local
```

Trên Windows, hosts file nằm tại:

```text
C:\Windows\System32\drivers\etc\hosts
```

## 9. Smoke Test Staging

Chạy các lệnh:

```bash
curl http://staging.dacn.local/
curl http://staging.dacn.local/api/health
curl http://staging.dacn.local/api/auth/health
curl http://staging.dacn.local/api/products/health
curl http://staging.dacn.local/api/order/health
```

Nếu endpoint fail, kiểm tra log:

```bash
kubectl -n dacn-staging logs deploy/dacn-staging-gateway
kubectl -n dacn-staging logs deploy/dacn-staging-auth
kubectl -n dacn-staging logs deploy/dacn-staging-product
kubectl -n dacn-staging logs deploy/dacn-staging-order
```

## 10. Load Test Và Validation

Chạy workflow `staging-validation.yml` trong repo app với input:

```text
image_tag=sha-xxxxxxx
staging_url=http://staging.dacn.local
run_10k_load_test=false
```

Trong Minikube local, không nên mặc định chạy 10.000 VUs. Nên bắt đầu bằng baseline nhỏ, sau đó tăng dần tải để phân tích bottleneck.

Khi cần test 10.000 VUs thật sự, dùng k6 Cloud hoặc distributed runners.

## 11. Promote Production-Like

Production-like resource đã có sẵn nhưng đang suspend:

```text
apps/dacn/production/helmrelease.yaml
```

Sau khi staging pass, tạo PR trong GitOps repo để:

1. Đổi `spec.suspend` từ `true` thành `false`.
2. Đổi `global.imageTag` thành đúng tag đã pass staging.

Ví dụ:

```yaml
spec:
  suspend: false

values:
  global:
    imageTag: sha-xxxxxxx
```

Sau khi merge, FluxCD deploy production-like vào namespace `dacn-prod`.

Kiểm tra:

```bash
kubectl -n dacn-prod get pods
kubectl -n dacn-prod get ingress
curl http://prod.dacn.local/api/health
```

## 12. Rollback

Rollback bằng Git:

```text
revert commit promote
hoặc đổi imageTag về sha đã pass trước đó
```

Sau khi push, FluxCD reconcile lại cluster theo trạng thái Git.

## 13. Kết Quả Cần Đưa Vào Báo Cáo

- Ảnh `kubectl get pods -A`.
- Ảnh FluxCD reconcile thành công.
- Ảnh staging endpoint pass smoke test.
- Ảnh Grafana dashboard CPU/memory/HPA.
- Kết quả k6 baseline/load test.
- Bảng image tag staging và production-like.
- Mô tả rollback bằng GitOps.
