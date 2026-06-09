# data

Desired state for lab MongoDB, Redis, and RabbitMQ.

Các resource hiện tại dùng Bitnami Helm chart:

```text
mongodb.yaml
redis.yaml
rabbitmq.yaml
```

Thiết kế này phục vụ Minikube lab. Production thật nên thay bằng managed database/cache/broker hoặc chart có HA, backup và secret management nghiêm túc hơn.
