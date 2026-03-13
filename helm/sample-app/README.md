# Sample App Helm Chart

A production-ready Helm chart for deploying a Node.js application with Prometheus metrics on Amazon EKS.

## Features

- **Prometheus Metrics**: Built-in metrics endpoint with custom business metrics
- **Health Checks**: Liveness and readiness probes
- **Auto-scaling**: Horizontal Pod Autoscaler based on CPU/Memory
- **Security**: Pod security contexts, non-root user, read-only root filesystem support
- **High Availability**: Pod anti-affinity rules, rolling updates
- **Monitoring**: ServiceMonitor support for Prometheus Operator
- **Ingress**: AWS ALB Ingress Controller support
- **Multi-Environment**: Separate values files for dev and prod

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- AWS Load Balancer Controller (for ingress)
- Prometheus Operator (optional, for ServiceMonitor)

## Application Structure

```
helm/sample-app/
├── Chart.yaml                 # Chart metadata
├── values.yaml                # Default values
├── values-dev.yaml           # Development environment values
├── values-prod.yaml          # Production environment values
├── templates/
│   ├── _helpers.tpl          # Template helpers
│   ├── deployment.yaml       # Deployment resource
│   ├── service.yaml          # Service resource
│   ├── serviceaccount.yaml   # ServiceAccount resource
│   ├── configmap.yaml        # ConfigMap resource
│   ├── ingress.yaml          # Ingress resource
│   ├── hpa.yaml              # HorizontalPodAutoscaler
│   └── servicemonitor.yaml   # ServiceMonitor (Prometheus Operator)
└── app/
    ├── server.js             # Node.js application
    ├── package.json          # NPM dependencies
    └── Dockerfile            # Container image definition
```

## Quick Start

### 1. Build the Docker Image

```bash
cd helm/sample-app/app

# Build the image
docker build -t sample-app:1.0.0 .

# Tag for ECR (replace with your ECR repository)
docker tag sample-app:1.0.0 <account-id>.dkr.ecr.<region>.amazonaws.com/sample-app:1.0.0

# Push to ECR
aws ecr get-login-password --region <region> | docker login --username AWS --password-stdin <account-id>.dkr.ecr.<region>.amazonaws.com
docker push <account-id>.dkr.ecr.<region>.amazonaws.com/sample-app:1.0.0
```

### 2. Install the Helm Chart

```bash
# Install with default values
helm install sample-app ./helm/sample-app

# Install with development values
helm install sample-app ./helm/sample-app -f ./helm/sample-app/values-dev.yaml

# Install with production values
helm install sample-app ./helm/sample-app -f ./helm/sample-app/values-prod.yaml

# Install to a specific namespace
helm install sample-app ./helm/sample-app -n production --create-namespace
```

### 3. Verify the Deployment

```bash
# Check deployment status
kubectl get all -l app.kubernetes.io/name=sample-app

# Check pods
kubectl get pods -l app.kubernetes.io/name=sample-app

# Check service
kubectl get svc -l app.kubernetes.io/name=sample-app

# Check HPA (if enabled)
kubectl get hpa -l app.kubernetes.io/name=sample-app
```

### 4. Access the Application

```bash
# Port forward to access locally
kubectl port-forward svc/sample-app 8080:80

# Access endpoints
curl http://localhost:8080/
curl http://localhost:8080/health
curl http://localhost:8080/metrics
curl http://localhost:8080/api/users
```

## Configuration

### Key Configuration Options

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replicaCount` | Number of replicas | `2` |
| `image.repository` | Image repository | `sample-app` |
| `image.tag` | Image tag | `1.0.0` |
| `service.type` | Service type | `ClusterIP` |
| `service.port` | Service port | `80` |
| `ingress.enabled` | Enable ingress | `false` |
| `autoscaling.enabled` | Enable HPA | `true` |
| `autoscaling.minReplicas` | Min replicas | `2` |
| `autoscaling.maxReplicas` | Max replicas | `10` |
| `resources.requests.cpu` | CPU request | `250m` |
| `resources.requests.memory` | Memory request | `256Mi` |
| `resources.limits.cpu` | CPU limit | `500m` |
| `resources.limits.memory` | Memory limit | `512Mi` |

### Update Image Repository

Edit `values.yaml` and update the image repository:

```yaml
image:
  repository: <account-id>.dkr.ecr.<region>.amazonaws.com/sample-app
  tag: "1.0.0"
```

### Enable Ingress

Edit `values.yaml` or use a custom values file:

```yaml
ingress:
  enabled: true
  className: "alb"
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
  hosts:
    - host: sample-app.example.com
      paths:
        - path: /
          pathType: Prefix
```

### Enable ServiceMonitor

If using Prometheus Operator:

```yaml
serviceMonitor:
  enabled: true
  interval: 30s
  scrapeTimeout: 10s
```

## Upgrading

```bash
# Upgrade using default values
helm upgrade sample-app ./helm/sample-app

# Upgrade with custom values
helm upgrade sample-app ./helm/sample-app -f ./helm/sample-app/values-prod.yaml

# Rollback to previous version
helm rollback sample-app
```

## Uninstalling

```bash
# Uninstall the release
helm uninstall sample-app

# Uninstall from specific namespace
helm uninstall sample-app -n production
```

## API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/` | GET | Welcome message with endpoint list |
| `/health` | GET | Health check endpoint |
| `/ready` | GET | Readiness check endpoint |
| `/metrics` | GET | Prometheus metrics |
| `/api/users` | GET | List users |
| `/api/users` | POST | Create user |
| `/api/orders` | GET | List orders |
| `/api/products` | GET | List products |
| `/api/error` | GET | Test error endpoint |

## Prometheus Metrics

The application exposes the following custom metrics:

- `http_requests_total` - Counter for total HTTP requests
- `http_request_duration_seconds` - Histogram for request duration
- `business_operations_total` - Counter for business operations

Plus default Node.js metrics from `prom-client`.

## Testing the Application

```bash
# Generate load
for i in {1..100}; do
  curl http://localhost:8080/api/users
  curl http://localhost:8080/api/orders
  sleep 0.1
done

# Check metrics
curl http://localhost:8080/metrics | grep http_requests_total
```

## Troubleshooting

### Pods not starting

```bash
# Check pod status
kubectl describe pod -l app.kubernetes.io/name=sample-app

# Check logs
kubectl logs -l app.kubernetes.io/name=sample-app --tail=100
```

### Image pull errors

Ensure your nodes have permission to pull from ECR:

```bash
# Verify image exists
aws ecr describe-images --repository-name sample-app

# Check node IAM role has ECR pull permissions
```

### HPA not scaling

```bash
# Check metrics server
kubectl get apiservice v1beta1.metrics.k8s.io

# Check HPA status
kubectl describe hpa sample-app
```

## Production Checklist

- [ ] Update image repository to ECR
- [ ] Set appropriate resource limits
- [ ] Enable and configure ingress
- [ ] Set up TLS certificates
- [ ] Configure ServiceMonitor for monitoring
- [ ] Set up proper logging
- [ ] Configure pod disruption budgets
- [ ] Set up network policies
- [ ] Enable pod security policies
- [ ] Configure backup strategy

## License

MIT
