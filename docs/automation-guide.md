# Automation Guide

Tài liệu này mô tả cách tự động hóa triển khai hệ thống DACN trên Minikube lab bằng GitHub Actions và FluxCD.

## 1. Mục Tiêu Tự Động Hóa

Luồng mong muốn:

```text
Developer push code vào repo app
-> GitHub Actions build/test/security/smoke
-> build và push image GHCR tag sha-xxxxxxx
-> GitHub Actions cập nhật imageTag staging trong dacn-gitops
-> FluxCD reconcile staging trên Minikube
-> chạy smoke/load validation
-> nếu pass thì promote cùng image tag sang production-like
```

GitHub Actions không chạy `kubectl apply` vào cluster. Actions chỉ cập nhật Git. FluxCD là thành phần duy nhất reconcile cluster từ Git state.

## 2. Scripts Hiện Có

Trong repo `dacn-gitops`:

```text
scripts/bootstrap-minikube.sh
scripts/validate-gitops.sh
scripts/set-image-tag.sh
scripts/promote-production.sh
scripts/smoke-test.sh
```

Trong repo app `My_DACN`:

```text
scripts/update-gitops-staging.sh
```

Script `update-gitops-staging.sh` được dùng bởi workflow `ci-main.yml` để sửa `apps/dacn/staging/helmrelease.yaml` trong repo GitOps.

## 3. Chuẩn Bị GitHub Secrets Và Variables

Trong repo app `My_DACN`, cấu hình:

```text
Settings -> Secrets and variables -> Actions
```

Secrets cần có:

```text
GITOPS_TOKEN
AUTH_ENV_DEV
PRODUCT_ENV_DEV
ORDER_ENV_DEV
GATEWAY_ENV_DEV
```

`GITOPS_TOKEN` là fine-grained personal access token có quyền:

```text
Repository: dacn-gitops
Permission: Contents read/write
```

Variables nên có:

```text
GITOPS_REPOSITORY=<owner>/dacn-gitops
```

Nếu không đặt `GITOPS_REPOSITORY`, workflow sẽ mặc định dùng:

```text
<github.repository_owner>/dacn-gitops
```

## 4. Bootstrap Minikube Và FluxCD

Chạy từ thư mục `dacn-gitops`:

```bash
GITHUB_OWNER="<github-user-or-org>" \
GITOPS_REPOSITORY="dacn-gitops" \
scripts/bootstrap-minikube.sh
```

Script sẽ:

```text
start Minikube profile dacn-lab
enable metrics-server
enable ingress
enable storage-provisioner
enable default-storageclass
flux bootstrap github --path clusters/lab
```

Nếu chỉ muốn tạo Minikube, chưa bootstrap Flux:

```bash
SKIP_FLUX_BOOTSTRAP=true scripts/bootstrap-minikube.sh
```

## 5. Validate GitOps Local

Render Kustomize:

```bash
scripts/validate-gitops.sh
```

Kiểm tra cả cluster/Flux:

```bash
CHECK_CLUSTER=true scripts/validate-gitops.sh
```

Lệnh này tương đương kiểm tra:

```text
kubectl kustomize clusters/lab
flux check
flux get sources
flux get helmreleases
kubectl get pods -A
```

## 6. CI Tự Cập Nhật Staging

Workflow `My_DACN/.github/workflows/ci-main.yml` đã có job:

```text
update-gitops-staging
```

Job này chỉ chạy khi push vào `main`.

Sau khi tất cả image đã push lên GHCR, job sẽ:

```text
compute image tag sha-xxxxxxx
checkout repo app
checkout repo dacn-gitops bằng GITOPS_TOKEN
chạy scripts/update-gitops-staging.sh
commit thay đổi imageTag vào dacn-gitops
push lên main của dacn-gitops
```

FluxCD đang chạy trong Minikube sẽ phát hiện commit mới và deploy staging.

## 7. Set Image Tag Thủ Công Khi Cần

Nếu muốn cập nhật staging thủ công:

```bash
scripts/set-image-tag.sh staging sha-xxxxxxx
```

Nếu muốn cập nhật production-like thủ công:

```bash
scripts/set-image-tag.sh production sha-xxxxxxx
```

Sau khi sửa, commit và push repo `dacn-gitops` để FluxCD reconcile.

## 8. Smoke Test Staging

Sau khi staging deploy xong:

```bash
scripts/smoke-test.sh http://staging.dacn.local
```

Kiểm tra production-like:

```bash
scripts/smoke-test.sh http://prod.dacn.local
```

## 9. Promote Production-Like

Sau khi staging validation pass:

```bash
scripts/promote-production.sh
```

Script sẽ:

```text
đọc imageTag hiện tại của staging
ghi imageTag đó sang production
đổi production HelmRelease từ suspend: true thành suspend: false
```

Cũng có thể chỉ định tag:

```bash
scripts/promote-production.sh sha-xxxxxxx
```

Sau đó tạo PR hoặc commit/push vào repo `dacn-gitops`. Khi thay đổi được merge, FluxCD deploy production-like.

## 10. Rollback

Rollback bằng Git:

```text
revert commit cập nhật imageTag
hoặc set imageTag về sha đã pass trước đó
```

Ví dụ:

```bash
scripts/set-image-tag.sh staging sha-oldgood
```

Sau khi push, FluxCD sẽ reconcile lại cluster.

## 11. Giới Hạn Hiện Tại

- Staging validation vẫn có thể chạy thủ công bằng workflow `staging-validation.yml`.
- Production-like promotion nên đi qua PR để có review.
- Secret trong repo hiện là placeholder cho lab, chưa phải SOPS/Sealed Secrets.
- ELK, OpenTelemetry và Jaeger chưa được tự động triển khai trong phase này.
- Nếu GHCR package private, cần tạo image pull secret trong `dacn-staging` và `dacn-prod`.
