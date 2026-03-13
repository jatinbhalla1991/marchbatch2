# Sample App - Docker Setup

Node.js application with Prometheus metrics, ready to deploy with Docker Compose or push to Docker Hub.

## Quick Start

### Option 1: Run Locally with Docker Compose

```bash
# Build and run the application
docker-compose up -d

# View logs
docker-compose logs -f sample-app

# Access the application
curl http://localhost:3000/health
curl http://localhost:3000/metrics
curl http://localhost:3000/api/users

# Run with load generator for testing
docker-compose --profile testing up -d

# Stop everything
docker-compose down
```

### Option 2: Build and Push to Docker Hub

```bash
# 1. Login to Docker Hub
docker login
# Username: jatinbhalla1991
# Password: [your-password]

# 2. Build the image
docker-compose build

# 3. Push to Docker Hub
docker-compose push

# Or use manual commands:
docker build -t jatinbhalla1991/sample-app:1.0.0 .
docker tag jatinbhalla1991/sample-app:1.0.0 jatinbhalla1991/sample-app:latest
docker push jatinbhalla1991/sample-app:1.0.0
docker push jatinbhalla1991/sample-app:latest
```

### Option 3: Run from Docker Hub

```bash
# Pull and run the published image
docker run -d -p 3000:3000 --name sample-app jatinbhalla1991/sample-app:1.0.0

# Check logs
docker logs -f sample-app

# Test
curl http://localhost:3000/health
```

## Available Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/` | GET | Welcome message and endpoint list |
| `/health` | GET | Health check (for Kubernetes probes) |
| `/ready` | GET | Readiness check |
| `/metrics` | GET | Prometheus metrics |
| `/api/users` | GET | List users |
| `/api/users` | POST | Create user |
| `/api/orders` | GET | List orders |
| `/api/products` | GET | List products |
| `/api/error` | GET | Test error endpoint |

## Docker Compose Commands

```bash
# Build the image
docker-compose build

# Start services
docker-compose up -d

# Start with load generator (for testing)
docker-compose --profile testing up -d

# View logs
docker-compose logs -f

# View specific service logs
docker-compose logs -f sample-app

# Check status
docker-compose ps

# Stop services
docker-compose stop

# Remove containers
docker-compose down

# Remove containers and volumes
docker-compose down -v

# Push image to Docker Hub
docker-compose push
```

## Testing

### Manual Testing

```bash
# Health check
curl http://localhost:3000/health

# Readiness check
curl http://localhost:3000/ready

# Get metrics
curl http://localhost:3000/metrics | grep http_requests_total

# API endpoints
curl http://localhost:3000/api/users
curl http://localhost:3000/api/orders
curl http://localhost:3000/api/products

# Create user
curl -X POST http://localhost:3000/api/users \
  -H "Content-Type: application/json" \
  -d '{"name":"John Doe","email":"john@example.com"}'

# Test error endpoint
curl http://localhost:3000/api/error
```

### Load Testing with Load Generator

```bash
# Start with load generator
docker-compose --profile testing up -d

# Watch metrics change
watch -n 1 "curl -s http://localhost:3000/metrics | grep http_requests_total"

# Check load generator logs
docker-compose logs -f load-generator
```

## Deploying to Kubernetes with Helm

After pushing to Docker Hub, deploy to your EKS cluster:

```bash
# From the helm/sample-app directory
cd ../..

# Install with Helm
helm install sample-app . -n default

# Or with specific values
helm install sample-app . -f values-prod.yaml -n production

# Verify deployment
kubectl get pods -l app.kubernetes.io/name=sample-app
kubectl port-forward svc/sample-app 8080:80
curl http://localhost:8080/health
```

## Metrics Available

### Custom Metrics

- `http_requests_total` - Total HTTP requests by method, route, and status code
- `http_request_duration_seconds` - Request duration histogram
- `business_operations_total` - Business operations by type and status

### Default Metrics

- `process_cpu_seconds_total` - Process CPU usage
- `process_resident_memory_bytes` - Process memory usage
- `nodejs_heap_size_total_bytes` - Node.js heap size
- `nodejs_heap_size_used_bytes` - Node.js heap used
- And many more from `prom-client`

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PORT` | 3000 | Application port |
| `NODE_ENV` | production | Node environment |
| `LOG_LEVEL` | info | Logging level |

## Troubleshooting

### Port Already in Use

```bash
# Find process using port 3000
netstat -ano | findstr :3000  # Windows
lsof -i :3000                  # macOS/Linux

# Stop conflicting containers
docker-compose down
docker stop sample-app
```

### Build Fails

```bash
# Clean Docker cache
docker system prune -a

# Rebuild without cache
docker-compose build --no-cache
```

### Container Exits Immediately

```bash
# Check logs
docker-compose logs sample-app

# Run interactively
docker-compose run --rm sample-app /bin/sh
```

## Production Considerations

1. **Image Tagging**: Use semantic versioning for production images
2. **Environment Variables**: Use `.env` file for sensitive data
3. **Resource Limits**: Add memory and CPU limits in docker-compose
4. **Security**: Run as non-root user (already configured)
5. **Monitoring**: Use Prometheus to scrape the `/metrics` endpoint
6. **Logging**: Configure proper log aggregation
7. **Health Checks**: Already configured in Dockerfile and docker-compose

## Next Steps

1. Push image to Docker Hub: `docker-compose push`
2. Deploy to Kubernetes: `helm install sample-app ../..`
3. Set up monitoring with Prometheus and Grafana
4. Configure ingress for external access
5. Set up CI/CD pipeline for automated builds
