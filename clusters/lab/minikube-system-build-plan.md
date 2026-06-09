# Minikube Lab System Build Plan

Tài liệu này mô tả kế hoạch xây dựng toàn bộ hệ thống DACN trên môi trường lab đã có sẵn server. Phạm vi tài liệu không bàn server là máy vật lý, VM hay cloud instance; giả định là server đã sẵn sàng và ta dùng Minikube để tạo Kubernetes cluster.

## Mục tiêu

Mục tiêu chính không phải chỉ là chạy được ứng dụng, mà là dựng được một workflow DevOps đủ hoàn chỉnh:

- Developer push code vào repo app.
- CI build, test và push container image.
- Repo `dacn-gitops` lưu desired state của cluster.
- FluxCD đồng bộ staging/production từ Git.
- Staging chạy validation đủ tin cậy trước khi promote production.
- Hệ thống có metrics, logs, traces để đánh giá hiệu năng và tìm nguyên nhân khi có lỗi.
- Lab có thể mô phỏng kịch bản tải lớn, ví dụ 10.000 user, để phân tích độ ổn định của hệ thống.

## Giả định

- Server đã được chuẩn bị sẵn.
- Server đã cài Docker hoặc container runtime tương thích với Minikube.
- Có quyền chạy `minikube`, `kubectl`, `helm`, `flux` và `git`.
- Image ứng dụng được push lên container registry, ví dụ GHCR hoặc Docker Hub.
- Domain lab có thể dùng hosts file hoặc `minikube tunnel`.
- Không lưu secret thật dưới dạng plaintext trong Git.

## Tech Stack Cốt Lõi

| Nhóm | Công nghệ | Vai trò |
| --- | --- | --- |
| Cluster | Minikube | Tạo Kubernetes cluster lab |
| CD/GitOps | FluxCD | Đồng bộ cluster theo Git |
| Package | Helm | Đóng gói ứng dụng và hạ tầng |
| Routing | NGINX Ingress Controller | Expose gateway/frontend |
| Data | MongoDB, Redis, RabbitMQ | Database, cache, message broker |
| Metrics | Prometheus, Grafana | Thu thập và hiển thị metric |
| Logs | Elasticsearch, Kibana, OTel/Fluent Bit | Tìm kiếm và phân tích log |
| Traces | OpenTelemetry Collector, Jaeger | Theo dõi request qua microservices |
| Load test | k6 | Kiểm thử tải và ngưỡng chất lượng |

## Tài Nguyên Khuyến Nghị

Vì ELK, Prometheus, Jaeger, MongoDB, Redis, RabbitMQ và nhiều service cùng chạy trên một cluster lab, cấu hình nên ở mức:

| Thành phần | Khuyến nghị |
| --- | --- |
| CPU | 8 vCPU |
| RAM | 14-16 GB |
| Disk | 80 GB |
| Kubernetes node | 1 node Minikube |

Nếu máy yếu hơn, ưu tiên triển khai theo từng phase và chỉ bật ELK khi cần phân tích log.

## Tạo Minikube Cluster

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

## Namespace Dự Kiến

```text
flux-system
ingress-nginx
observability
data
dacn-staging
dacn-prod
```

Ý nghĩa:

- `flux-system`: FluxCD controllers.
- `ingress-nginx`: ingress controller.
- `observability`: Prometheus, Grafana, Elasticsearch, Kibana, OTel Collector, Jaeger.
- `data`: MongoDB, Redis, RabbitMQ.
- `dacn-staging`: môi trường staging.
- `dacn-prod`: môi trường production-like.

## Bootstrap FluxCD

Sau khi tạo repo `dacn-gitops` trên GitHub:

```bash
flux bootstrap github \
  --owner=<github-user-or-org> \
  --repository=dacn-gitops \
  --branch=main \
  --path=clusters/lab \
  --personal
```

Sau bootstrap, FluxCD sẽ đọc thư mục `clusters/lab` và tự reconcile các manifest/Kustomization được định nghĩa trong repo.

## Layout GitOps Mong Muốn

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

Nguyên tắc tổ chức:

- `clusters/lab`: entrypoint mà FluxCD đọc.
- `infrastructure`: thành phần nền tảng của cluster.
- `apps`: nơi cluster gọi tới cấu hình ứng dụng.
- `apps/dacn/base`: cấu hình chung.
- `apps/dacn/staging`: cấu hình staging.
- `apps/dacn/production`: cấu hình production-like.
- `secrets`: chỉ chứa template hoặc secret đã mã hóa.

## Phase 1: Platform Tối Thiểu

Mục tiêu của phase này là có cluster hoạt động và có GitOps loop.

Cần triển khai:

- Minikube cluster.
- NGINX Ingress Controller.
- FluxCD.
- Namespace chuẩn.
- StorageClass mặc định.
- Metrics Server.

Kiểm tra:

```bash
kubectl get nodes
kubectl get pods -A
flux check
```

Definition of Done:

- Cluster healthy.
- FluxCD reconcile được repo.
- Ingress controller chạy ổn định.

## Phase 2: Data Layer

Mục tiêu là cung cấp các dependency runtime cho microservices.

Cần triển khai:

- MongoDB cho các service cần database.
- Redis cho cache/token/session nếu ứng dụng dùng.
- RabbitMQ cho message queue.

Khuyến nghị trong lab:

- Dùng Helm chart có sẵn, ví dụ Bitnami chart.
- Chạy replica thấp để tiết kiệm tài nguyên.
- Dùng persistent volume nhưng retention ngắn.
- Không cố mô phỏng database HA nếu trọng tâm đồ án là workflow và performance validation.

Definition of Done:

- Service trong namespace `dacn-staging` connect được tới MongoDB, Redis, RabbitMQ.
- Có secret/config reference rõ ràng.
- Không hard-code connection string trong source code.

## Phase 3: Metrics

Mục tiêu là biết hệ thống đang khỏe hay yếu bằng số liệu.

Cần triển khai:

- Prometheus.
- Grafana.
- Node Exporter.
- kube-state-metrics.
- ServiceMonitor hoặc PodMonitor nếu chart hỗ trợ.

Metric cần quan sát:

- CPU, memory, network, disk.
- Pod restart count.
- Request rate.
- Error rate.
- Latency p95/p99.
- MongoDB/Redis/RabbitMQ health.

Definition of Done:

- Grafana xem được dashboard cluster.
- Prometheus scrape được workload quan trọng.
- Có baseline metric trước khi chạy load test.

## Phase 4: Logs Với ELK

Mục tiêu là truy vết lỗi bằng log có khả năng tìm kiếm tốt.

ELK nặng hơn Loki, nhưng hợp lý trong đồ án này nếu mục tiêu là chứng minh khả năng phân tích log chuyên sâu:

- Elasticsearch mạnh ở full-text search, filter, aggregation và phân tích log có cấu trúc.
- Kibana hỗ trợ query, dashboard và drill-down log tốt.
- Khi hệ thống microservices phát sinh lỗi phân tán, khả năng search theo `trace_id`, `user_id`, `request_id`, status code hoặc service name rất có giá trị.
- ELK phù hợp để trình bày góc nhìn vận hành doanh nghiệp: log không chỉ để xem dòng lỗi, mà còn để phân tích sự cố, hành vi hệ thống và xu hướng lỗi.

Phản biện khi bị hỏi ELK quá nặng:

- Đúng, ELK nặng hơn Loki, nên production cần sizing riêng.
- Trong lab, ta không triển khai ELK theo kiểu production HA.
- Ta dùng Elasticsearch single-node, retention ngắn, resource limit rõ ràng.
- Ta chỉ giữ log cần thiết cho kiểm thử và phân tích, ví dụ 1-3 ngày.
- Việc chọn ELK phục vụ mục tiêu học thuật: chứng minh năng lực log analytics và incident analysis, không phải tối ưu chi phí hạ tầng nhỏ nhất.

Triển khai lab nên làm:

- Elasticsearch single-node.
- Kibana một replica.
- OTel Collector hoặc Fluent Bit để ship log.
- Chuẩn hóa log JSON từ ứng dụng nếu có thể.
- Gắn `trace_id`/`request_id` vào log để liên kết log với trace.

Definition of Done:

- Kibana xem được log theo service.
- Query được lỗi theo status code hoặc keyword.
- Log có timestamp, service name, environment và request identifier.

## Phase 5: Tracing

Mục tiêu là nhìn được một request đi qua gateway và các microservices như thế nào.

Cần triển khai:

- OpenTelemetry Collector.
- Jaeger all-in-one cho lab.
- Instrument gateway/service nếu source code hỗ trợ.

Trace cần chứng minh:

- Request vào API Gateway.
- Gateway gọi Auth/Product/Order service.
- Service gọi database/cache/message broker.
- Có latency từng span.

Definition of Done:

- Jaeger hiển thị trace end-to-end.
- Có thể chỉ ra service nào làm tăng latency khi load test.

## Phase 6: Deploy DACN Staging

Mục tiêu là đưa ứng dụng lên staging bằng FluxCD.

Luồng đề xuất:

1. CI trong repo app build image.
2. CI push image với tag bất biến, ví dụ `sha-a1b2c3d`.
3. Cập nhật image tag trong `dacn-gitops/apps/dacn/staging`.
4. FluxCD reconcile staging.
5. Chạy smoke test và load test vào staging endpoint.

Ingress staging:

```text
staging.dacn.local
```

Nếu dùng hosts file:

```bash
minikube ip -p dacn-lab
```

Sau đó map IP vào hosts:

```text
<minikube-ip> staging.dacn.local
<minikube-ip> prod.dacn.local
```

Definition of Done:

- Frontend/gateway truy cập được qua ingress.
- Các service chạy healthy.
- Staging dùng secret/config riêng.
- Smoke test pass.

## Phase 7: Staging Validation

Đây là trọng tâm chất lượng của đồ án.

Validation nên gồm:

- Smoke test: endpoint chính còn sống.
- Integration test: luồng nghiệp vụ quan trọng chạy được.
- Contract test nếu có service giao tiếp phức tạp.
- Load test bằng k6.
- Kiểm tra metric/log/trace trong lúc test.

Kịch bản 10.000 user không nên chỉ hiểu là 10.000 request. Cần định nghĩa rõ:

- 10.000 concurrent virtual users, hoặc
- 10.000 registered users trong tập dữ liệu test, hoặc
- 10.000 user/session trong một khoảng thời gian.

Với đồ án này, nên trình bày là:

- Dùng k6 mô phỏng tải tăng dần tới 10.000 virtual users nếu tài nguyên cho phép.
- Nếu lab không đủ tải tuyệt đối, dùng kết quả thực nghiệm nhỏ hơn để suy luận giới hạn, bottleneck và capacity planning.

Ngưỡng tham khảo:

| Chỉ số | Mục tiêu |
| --- | --- |
| Error rate | < 1% |
| p95 latency | < 800 ms |
| p99 latency | < 1500 ms |
| Pod crash/restart | Không tăng bất thường |
| CPU/memory | Không vượt giới hạn kéo dài |

Definition of Done:

- Có báo cáo kết quả k6.
- Có screenshot/dashboard metric.
- Có log/trace minh họa khi có lỗi hoặc latency cao.
- Có kết luận bottleneck và đề xuất cải thiện.

## Phase 8: Promote Production-Like

Mục tiêu là chứng minh quy trình đưa bản đã kiểm thử lên production.

Luồng đề xuất:

1. Staging validation pass.
2. Tạo pull request trong `dacn-gitops`.
3. Copy image tag đã pass từ staging sang production.
4. Review thay đổi.
5. Merge vào `main`.
6. FluxCD reconcile `dacn-prod`.
7. Theo dõi metric/log/trace sau deploy.

Không dùng GitHub Actions để chạy `kubectl apply` hoặc `helm upgrade` trực tiếp.

Definition of Done:

- Production-like chạy cùng image đã pass staging.
- Có lịch sử Git cho việc promote.
- Có rollback path bằng cách revert commit image tag.

## Thứ Tự Ưu Tiên Triển Khai

1. Minikube + kubectl + ingress.
2. FluxCD bootstrap.
3. Namespace và GitOps skeleton.
4. Data layer tối thiểu.
5. Deploy DACN staging.
6. Smoke test staging.
7. Prometheus + Grafana.
8. k6 load test cơ bản.
9. ELK logging.
10. OTel + Jaeger tracing.
11. Load test 10.000 user hoặc capacity test tương đương.
12. Production-like promotion.

Thứ tự này giúp tránh đồ án bị quá nặng ngay từ đầu. Ta dựng được workflow chính trước, sau đó mới tăng độ sâu observability và performance analysis.

## Definition of Done Toàn Hệ Thống

Hệ thống lab được xem là hoàn thiện khi:

- Cluster Minikube chạy ổn định.
- FluxCD reconcile được toàn bộ desired state.
- Staging và production-like tách namespace/config.
- Ứng dụng truy cập được qua ingress.
- Database/cache/message broker hoạt động.
- Metrics hiển thị được trên Grafana.
- Logs truy vấn được trên Kibana.
- Traces xem được trên Jaeger.
- Có staging validation report.
- Có kết quả load test và phân tích bottleneck.
- Có quy trình promote/rollback bằng GitOps.

## Giới Hạn Cần Nói Rõ Trong Báo Cáo

Minikube lab không phải production thật. Vì vậy không nên tuyên bố hệ thống đã sẵn sàng vận hành production ở quy mô doanh nghiệp.

Cách diễn đạt đúng trọng tâm hơn:

- Lab chứng minh workflow DevOps từ code tới production-like.
- Lab chứng minh cách kiểm tra chất lượng trước khi phát hành.
- Lab chứng minh năng lực quan sát hệ thống bằng metrics, logs và traces.
- Load test giúp phát hiện bottleneck và ước lượng capacity.
- Production thật cần bổ sung HA, backup, disaster recovery, autoscaling, security hardening và sizing hạ tầng riêng.
