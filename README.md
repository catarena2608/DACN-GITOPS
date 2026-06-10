# dacn-gitops

Repository GitOps cho đồ án DACN.

Repo này chỉ mô tả **desired state của cluster**: namespace, ingress, database, observability, secret reference, HelmRelease/Kustomization và cấu hình triển khai ứng dụng theo môi trường.

Source code, Dockerfile, Helm chart gốc, test script và tài liệu kỹ thuật vẫn nằm ở repo app hiện tại. Trong workspace này repo app đang là `My_DACN`; khi hoàn thiện có thể đổi tên thư mục thành `dacn-app`.

## Mục tiêu

- Dùng FluxCD làm CD controller.
- Dùng Git làm nguồn sự thật cho trạng thái cluster.
- Tách rõ cấu hình `staging` và `production`.
- Không commit secret thật lên GitHub.
- Cho phép dựng lab bằng Minikube nhưng vẫn giữ tư duy gần với production.

## Cấu trúc hiện tại

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
│       │   ├── ingress-nginx/
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

## Kế hoạch triển khai lab

Xem tài liệu chính tại:

- [clusters/lab/minikube-system-build-plan.md](clusters/lab/minikube-system-build-plan.md)
- [clusters/lab/minikube-deployment-runbook.md](clusters/lab/minikube-deployment-runbook.md)
- [docs/automation-guide.md](docs/automation-guide.md)

## Script tự động hóa

Các script vận hành Minikube/GitOps nằm trong:

```text
scripts/
```

Luồng CI tự cập nhật staging image tag được mô tả trong:

```text
docs/automation-guide.md
```

## Nguyên tắc

- GitHub Actions chỉ build/test/push image ở repo app.
- FluxCD đọc repo này và tự đồng bộ cluster.
- Image tag phải là tag bất biến, ví dụ `sha-<commit>`, không dùng `latest` cho staging/production.
- Secret thật được quản lý bằng External Secrets, Sealed Secrets hoặc SOPS; thư mục `secrets/` chỉ chứa template hoặc encrypted manifest.
- Mọi thay đổi lên production nên đi qua pull request để có lịch sử kiểm soát.
