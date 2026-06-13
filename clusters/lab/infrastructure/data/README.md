# data

Desired state for lab MongoDB, Redis, and RabbitMQ.

The current resources use Bitnami Helm charts:

```text
mongodb.yaml
redis.yaml
rabbitmq.yaml
```

This design is intended for the Minikube lab. A real production environment should use managed database/cache/broker services, or HA charts with backup and serious secret management.

