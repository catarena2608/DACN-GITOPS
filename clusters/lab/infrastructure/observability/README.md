# observability

Desired state for Prometheus, Grafana, OpenTelemetry, Jaeger, Elasticsearch, and Kibana.

Phase hiện tại bật trước Prometheus và Grafana qua `kube-prometheus-stack`.

```text
prometheus-stack.yaml
```

OpenTelemetry, Jaeger và Elasticsearch/Kibana nên triển khai ở phase sau nếu Minikube đủ tài nguyên.
