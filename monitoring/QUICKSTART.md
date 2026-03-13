# Quick Access Guide - Monitoring Stack

## ✅ Deployment Status

All components are successfully deployed and running!

```
✓ Prometheus (2 replicas) - Metrics collection
✓ Grafana (1 replica) - Visualization  
✓ Demo App (2 replicas) - Sample application with metrics
✓ Load Generator (2 replicas) - Traffic generator
```

## 🌐 Access URLs

### Option 1: Using Port-Forward (Recommended for Local)

#### Prometheus
```bash
kubectl port-forward -n monitoring svc/prometheus 9090:9090
```
Then visit: **http://localhost:9090**

#### Grafana
```bash
kubectl port-forward -n monitoring svc/grafana 3000:3000
```
Then visit: **http://localhost:3000**
- Username: `admin`
- Password: `admin123`

#### Demo App
```bash
kubectl port-forward -n monitoring svc/demo-app 3000:3000
```
Then visit: **http://localhost:3000**

### Option 2: Using LoadBalancer (External Access)

Get the external URLs:
```bash
kubectl get svc -n monitoring
```

Access via the EXTERNAL-IP addresses shown for:
- `prometheus-external` on port 9090
- `grafana-external` on port 3000  
- `demo-app-external` on port 3000

## 📊 View Metrics in Prometheus

1. Access Prometheus UI (see above)

2. Try these sample queries:

**Request rate per endpoint:**
```promql
rate(http_requests_total{namespace="monitoring"}[1m])
```

**95th percentile response time:**
```promql
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket{namespace="monitoring"}[5m]))
```

**Total requests by status code:**
```promql
sum by (status_code) (rate(http_requests_total{namespace="monitoring"}[5m]))
```

**Error rate:**
```promql
sum(rate(http_requests_total{namespace="monitoring",status_code=~"5.."}[5m]))
```

**Business operations:**
```promql
rate(business_operations_total{namespace="monitoring"}[1m])
```

3. Click **Graph** to visualize the metrics

4. Navigate to **Status → Targets** to see all scrape targets

## 📈 Create Grafana Dashboard

### Quick Import

1. Access Grafana (login with admin/admin123)

2. Go to **Dashboards → Import** (or click the + icon → Import)

3. **Upload** the file: `sample-app/grafana-dashboard.json`

4. Select **Prometheus** as the datasource

5. Click **Import**

### Manual Dashboard Creation

1. Click **+ → Dashboard → Add new panel**

2. In the query editor, paste a PromQL query:
   ```promql
   rate(http_requests_total{namespace="monitoring"}[1m])
   ```

3. Choose visualization type (Graph, Gauge, Stat, etc.)

4. Click **Apply** and **Save dashboard**

### Import Community Dashboards

1. Go to **Dashboards → Import**

2. Enter dashboard ID:
   - **Kubernetes Pod Monitoring**: 6417
   - **Node Exporter Full**: 1860
   - **Prometheus Stats**: 3662

3. Click **Load** → Select Prometheus datasource → **Import**

## 🔍 Verify Everything is Working

### Check Pod Status
```bash
kubectl get pods -n monitoring
```
All pods should show `Running` status.

### View Load Generator Logs
```bash
kubectl logs -n monitoring deployment/load-generator --tail=20 -f
```
You should see continuous HTTP requests being made.

### View Demo App Logs
```bash
kubectl logs -n monitoring deployment/demo-app --tail=20 -f
```
You should see "App listening on port 3000" message.

### Test Demo App Endpoints
```bash
# Port-forward first
kubectl port-forward -n monitoring svc/demo-app 3000:3000

# In another terminal:
curl http://localhost:3000/
curl http://localhost:3000/health
curl http://localhost:3000/metrics
curl http://localhost:3000/api/users
```

## 📊 What You Should See

### In Prometheus
- Multiple targets showing as **UP** in Status → Targets
- Growing metrics counters
- Request rate graphs showing activity
- Response time histograms with data points

### In Grafana Dashboard
- **Request Rate**: 2-4 requests/second (from 2 load generator replicas)
- **Response Times**: 0-2 seconds depending on endpoint
- **Status Codes**: Mostly 200, some 201, occasional 500
- **Business Operations**: Steady increase in counters
- **Resource Usage**: Low CPU (~5-10%) and memory usage

### Expected Traffic Pattern
- 40% GET /api/users (200 OK, ~0-1s latency)
- 30% GET /api/orders (200 OK, ~0-2s latency)
- 15% POST /api/users (201/500, ~90% success)
- 10% GET / (200 OK, fast)
- 5% GET /api/error (500 Error, intentional)

## 🎯 Useful Prometheus Queries

```promql
# Total requests in last 5 minutes
increase(http_requests_total{namespace="monitoring"}[5m])

# Average response time
avg(rate(http_request_duration_seconds_sum{namespace="monitoring"}[5m]) / rate(http_request_duration_seconds_count{namespace="monitoring"}[5m]))

# Success rate (non-5xx responses)
sum(rate(http_requests_total{namespace="monitoring",status_code!~"5.."}[5m])) / sum(rate(http_requests_total{namespace="monitoring"}[5m])) * 100

# Requests per pod
sum by (pod) (rate(http_requests_total{namespace="monitoring"}[1m]))

# Memory usage
process_resident_memory_bytes{namespace="monitoring",job="demo-app"}
```

## 🔧 Troubleshooting

### Pods not starting?
```bash
kubectl describe pod <pod-name> -n monitoring
kubectl logs <pod-name> -n monitoring
```

### Metrics not showing?
1. Check Prometheus targets: Status → Targets
2. Verify pod annotations include `prometheus.io/scrape: "true"`
3. Ensure metrics endpoint is accessible: `curl http://<pod-ip>:3000/metrics`

### Load generator not working?
```bash
kubectl logs -n monitoring deployment/load-generator
```
Should show successful HTTP requests, not curl errors.

### Grafana shows "No Data"?
1. Verify Prometheus datasource is configured
2. Check if metrics exist in Prometheus first
3. Adjust time range in top-right corner
4. Verify namespace label in queries: `{namespace="monitoring"}`

## 📚 File Structure

```
monitoring/
├── README.md                          # Main monitoring setup guide
├── namespace.yaml                     # Monitoring namespace
├── prometheus-*.yaml                  # Prometheus configuration files
├── grafana-*.yaml                     # Grafana configuration files
├── deploy-all.yaml                    # Single-file deployment
├── deploy.ps1 / deploy.sh            # Deployment scripts
└── sample-app/
    ├── README.md                      # Sample app guide (detailed)
    ├── deployment.yaml                # Demo app deployment
    ├── load-generator.yaml            # Traffic generator
    ├── grafana-dashboard.json         # Pre-built dashboard
    ├── server.js                      # Application code (reference)
    ├── package.json                   # Node.js dependencies (reference)
    └── Dockerfile                     # Container image (reference)
```

## 🧹 Cleanup

### Remove only the sample app and load generator:
```bash
kubectl delete -f sample-app/deployment.yaml
kubectl delete -f sample-app/load-generator.yaml
```

### Remove everything:
```bash
kubectl delete namespace monitoring
```

⚠️ **Warning**: This deletes all data including Prometheus metrics and Grafana dashboards!

## 🎓 Next Steps

1. ✅ Explore Prometheus queries in the UI
2. ✅ Import and customize Grafana dashboards
3. ✅ Watch real-time metrics being generated
4. ⬜ Add alerting rules (if needed)
5. ⬜ Create custom dashboards for your workloads
6. ⬜ Install EBS CSI driver for persistent storage
7. ⬜ Deploy your own applications with metrics

## 💡 Tips

- Use the Prometheus UI to explore available metrics
- Grafana's dashboard templates are great starting points
- Label your metrics well for easier filtering
- Use `rate()` for counters and `histogram_quantile()` for histograms
- Monitor the monitoring stack itself (Prometheus/Grafana resource usage)

---

**Happy Monitoring! 🎉**
