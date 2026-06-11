# observability

Desired state for Prometheus, Grafana, OpenTelemetry, Jaeger, Elasticsearch, and Kibana.

```text
prometheus-stack.yaml       Prometheus, Grafana, node exporter, kube-state-metrics
otel-collector.yaml         OTLP receiver for application logs and traces; exports them to Elasticsearch
jaeger.yaml                 Jaeger UI/query configured to read traces from Elasticsearch
elasticsearch-kibana.yaml   Elasticsearch and Kibana for logs and traces storage/search
```

Lab access:

```bash
kubectl -n observability port-forward svc/kube-prometheus-stack-grafana 3001:80
kubectl -n observability port-forward svc/jaeger-query 16686:16686
kubectl -n observability port-forward svc/kibana 5601:5601
```

Local URLs:

```text
Grafana: http://localhost:3001
Jaeger:  http://localhost:16686
Kibana:  http://localhost:5601
```

Minikube hosts, if ingress is enabled:

```text
jaeger.dacn.local
kibana.dacn.local
```

Notes:

```text
Node exporter and kube-state-metrics are provided by kube-prometheus-stack for node and Kubernetes metrics.
Prometheus scrapes metrics and Grafana queries Prometheus to render dashboards.
OpenTelemetry Collector receives OTLP logs and traces from instrumented applications, then writes them to Elasticsearch.
Kibana queries Elasticsearch for keyword log search and filtering.
Jaeger UI queries Elasticsearch to visualize traces and spans.
Elasticsearch and Kibana are intentionally single-node lab deployments, not production HA deployments.
```
