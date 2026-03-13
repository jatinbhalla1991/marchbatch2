# Sample Application for Prometheus & Grafana Monitoring

This directory contains a demo Node.js application instrumented with Prometheus metrics, along with a load generator to create traffic for testing your monitoring stack.

## 📁 Files

- **server.js** - Node.js application with Prometheus client integration
- **package.json** - Node.js dependencies
- **Dockerfile** - Container image definition (optional)
- **deployment.yaml** - Kubernetes deployment, service, and ConfigMap
- **load-generator.yaml** - Automated traffic generator
- **grafana-dashboard.json** - Pre-built Grafana dashboard

## 🚀 Quick Start

### 1. Deploy the Application

```bash
kubectl apply -f deployment.yaml
```

This creates:
- 2 replicas of the demo application
- ClusterIP service for internal access
- LoadBalancer service for external access

### 2. Deploy the Load Generator

```bash
kubectl apply -f load-generator.yaml
```

This creates:
- 2 replicas of the load generator
- Automatically generates HTTP traffic to various endpoints

### 3. Verify Deployment

```bash
kubectl get pods -n monitoring
```

You should see:
```
NAME                             READY   STATUS    RESTARTS   AGE
demo-app-xxxxx-xxxxx             1/1     Running   0          2m
demo-app-xxxxx-xxxxx             1/1     Running   0          2m
load-generator-xxxxx-xxxxx       1/1     Running   0          1m
load-generator-xxxxx-xxxxx       1/1     Running   0          1m
prometheus-xxxxx-xxxxx           1/1     Running   0          10m
grafana-xxxxx-xxxxx              1/1     Running   0          10m
```

## 📊 Application Endpoints

The demo app exposes the following endpoints:

- **GET /** - Home endpoint with API info
- **GET /health** - Health check endpoint
- **GET /metrics** - Prometheus metrics endpoint
- **GET /api/users** - Simulated user list (random latency 0-1s)
- **POST /api/users** - Create user (90% success, 10% error)
- **GET /api/orders** - Simulated order list (random latency 0-2s)
- **GET /api/error** - Always returns 500 error (for testing)

## 📈 Metrics Exposed

### HTTP Metrics

- **http_requests_total** - Counter of total HTTP requests by method, route, and status code
- **http_request_duration_seconds** - Histogram of request durations

### Business Metrics

- **business_operations_total** - Counter of business operations by type and status

### Default Metrics

- **process_cpu_seconds_total** - CPU usage
- **process_resident_memory_bytes** - Memory usage
- **nodejs_heap_size_total_bytes** - Node.js heap size
- **nodejs_heap_size_used_bytes** - Node.js heap used

## 🔍 View Metrics in Prometheus

### 1. Port-Forward to Prometheus

```bash
kubectl port-forward -n monitoring svc/prometheus 9090:9090
```

### 2. Open Prometheus UI

Navigate to: http://localhost:9090

### 3. Try these queries:

**Request rate per second:**
```promql
rate(http_requests_total{namespace="monitoring"}[1m])
```

**95th percentile response time:**
```promql
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket{namespace="monitoring"}[5m]))
```

**Requests by status code:**
```promql
sum by (status_code) (rate(http_requests_total{namespace="monitoring"}[5m]))
```

**Business operations rate:**
```promql
rate(business_operations_total{namespace="monitoring"}[1m])
```

**Error rate:**
```promql
sum(rate(http_requests_total{namespace="monitoring",status_code=~"5.."}[5m]))
```

## 📊 Create Grafana Dashboard

### Method 1: Import Pre-built Dashboard

1. Port-forward to Grafana:
   ```bash
   kubectl port-forward -n monitoring svc/grafana 3000:3000
   ```

2. Open Grafana: http://localhost:3000
   - Username: `admin`
   - Password: `admin123`

3. Go to **Dashboards → Import**

4. Upload `grafana-dashboard.json` or paste its contents

5. Select **Prometheus** as the datasource

6. Click **Import**

### Method 2: Create Dashboard Manually

1. Click **+ → Dashboard → Add new panel**

2. Use PromQL queries from the examples above

3. Configure visualization type (Graph, Gauge, Stat, etc.)

4. Save the dashboard

### Popular Dashboard IDs to Import

You can also import these community dashboards:

- **Node Exporter Full** - ID: 1860
- **Kubernetes Pod Monitoring** - ID: 6417
- **Prometheus Stats** - ID: 3662

## 🧪 Testing and Verification

### Test the Application Directly

```bash
# Port-forward to the demo app
kubectl port-forward -n monitoring svc/demo-app 3000:3000

# Test endpoints
curl http://localhost:3000/
curl http://localhost:3000/health
curl http://localhost:3000/api/users
curl http://localhost:3000/metrics
```

### View Load Generator Logs

```bash
kubectl logs -n monitoring deployment/load-generator --tail=50 -f
```

You should see output like:
```
2026-03-13 05:19:00 - GET /api/users
2026-03-13 05:19:02 - GET /api/orders
2026-03-13 05:19:04 - POST /api/users
```

### Check Prometheus Targets

1. Go to Prometheus UI: http://localhost:9090
2. Click **Status → Targets**
3. Look for `demo-app` endpoints
4. Status should be **UP**

## 🎯 What to Look For

### In Prometheus

- Metrics are being scraped every 15 seconds
- Multiple time series for `http_requests_total`
- Growing counter values over time
- Histogram buckets for request durations

### In Grafana

With the load generator running, you should see:

- **Request Rate**: ~2-4 requests per second across both replicas
- **Response Times**: 0-2 seconds depending on endpoint
- **Status Codes**: Mostly 200s, occasional 500s (~10% on POST, 5% on error endpoint)
- **Business Operations**: Steady growth in operation counters
- **Resource Usage**: Low CPU and memory usage

## 🛠️ Customization

### Adjust Load Pattern

Edit `load-generator.yaml` to change:
- Request frequency (change `sleep` duration)
- Endpoint distribution (adjust `RAND` thresholds)
- Number of replicas

### Add Custom Metrics

Edit the inline script in `deployment.yaml` to add:
- New Counter metrics with `.inc()`
- New Gauge metrics with `.set(value)`
- New Histogram metrics with `.observe(value)`

Example:
```javascript
const customGauge = new promClient.Gauge({
  name: 'custom_metric_name',
  help: 'Description of the metric',
  labelNames: ['label1', 'label2']
});
register.registerMetric(customGauge);
customGauge.labels('value1', 'value2').set(42);
```

### Scale the Application

```bash
# Scale demo app
kubectl scale deployment demo-app -n monitoring --replicas=3

# Scale load generator
kubectl scale deployment load-generator -n monitoring --replicas=3
```

## 📝 Annotations for Prometheus Scraping

The deployment includes these important annotations:

```yaml
annotations:
  prometheus.io/scrape: "true"   # Enable scraping
  prometheus.io/port: "3000"     # Port to scrape
  prometheus.io/path: "/metrics" # Metrics endpoint
```

These tell Prometheus to automatically discover and scrape this application.

## 🧹 Cleanup

```bash
# Remove demo app and load generator
kubectl delete -f deployment.yaml
kubectl delete -f load-generator.yaml

# Or delete everything in the monitoring namespace
kubectl delete namespace monitoring
```

## 📚 Learn More

- [Prometheus Documentation](https://prometheus.io/docs/)
- [prom-client (Node.js)](https://github.com/siimon/prom-client)
- [Grafana Dashboards](https://grafana.com/grafana/dashboards/)
- [PromQL Basics](https://prometheus.io/docs/prometheus/latest/querying/basics/)

## 🎓 Next Steps

1. **Create Alerts**: Add alerting rules in Prometheus
2. **Add Alertmanager**: Route alerts to Slack, email, etc.
3. **Service Mesh**: Integrate with Istio for deeper insights
4. **Distributed Tracing**: Add Jaeger or Tempo
5. **Log Aggregation**: Add Loki or ELK stack
6. **Custom Dashboards**: Build dashboards for your specific needs

## 💡 Tips

- Metrics are cumulative - use `rate()` or `increase()` for meaningful graphs
- Use label carefully - each unique label combination creates a new time series
- Monitor the cardinality of your metrics to avoid overwhelming Prometheus
- Use recording rules for frequently calculated queries
- Set appropriate retention periods based on your storage capacity
