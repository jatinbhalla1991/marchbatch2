# Prometheus and Grafana Monitoring for EKS Cluster

This directory contains Kubernetes manifests for deploying Prometheus and Grafana to monitor your EKS cluster.

## Architecture Overview

- **Prometheus**: Metrics collection and storage
- **Grafana**: Visualization and dashboards
- **Persistent Storage**: AWS EBS volumes (gp2) for data persistence

## Prerequisites

1. EKS cluster up and running
2. kubectl configured to access your EKS cluster
3. Sufficient permissions to create namespaces, deployments, and services

## Quick Start

### Option 1: Deploy All at Once

```bash
# Deploy all components
kubectl apply -f namespace.yaml
kubectl apply -f prometheus-rbac.yaml
kubectl apply -f prometheus-config.yaml
kubectl apply -f prometheus-pvc.yaml
kubectl apply -f prometheus-deployment.yaml
kubectl apply -f grafana-config.yaml
kubectl apply -f grafana-pvc.yaml
kubectl apply -f grafana-deployment.yaml
```

### Option 2: Deploy Step by Step

#### 1. Create Monitoring Namespace

```bash
kubectl apply -f namespace.yaml
```

#### 2. Deploy Prometheus

```bash
# Create RBAC resources
kubectl apply -f prometheus-rbac.yaml

# Create ConfigMap with Prometheus configuration
kubectl apply -f prometheus-config.yaml

# Create Persistent Volume Claim
kubectl apply -f prometheus-pvc.yaml

# Deploy Prometheus
kubectl apply -f prometheus-deployment.yaml
```

#### 3. Deploy Grafana

```bash
# Create Grafana datasource configuration
kubectl apply -f grafana-config.yaml

# Create Persistent Volume Claim
kubectl apply -f grafana-pvc.yaml

# Deploy Grafana
kubectl apply -f grafana-deployment.yaml
```

## Verify Deployment

### Check Pod Status

```bash
kubectl get pods -n monitoring
```

Expected output:
```
NAME                          READY   STATUS    RESTARTS   AGE
prometheus-xxxxxxxxxx-xxxxx   1/1     Running   0          2m
grafana-xxxxxxxxxx-xxxxx      1/1     Running   0          2m
```

### Check Services

```bash
kubectl get svc -n monitoring
```

### Check Persistent Volume Claims

```bash
kubectl get pvc -n monitoring
```

## Access the Applications

### Access Prometheus

**Using Port Forward:**
```bash
kubectl port-forward -n monitoring svc/prometheus 9090:9090
```
Then access: http://localhost:9090

**Using LoadBalancer (External):**
```bash
# Get the external IP
kubectl get svc prometheus-external -n monitoring

# Access Prometheus at: http://<EXTERNAL-IP>:9090
```

### Access Grafana

**Using Port Forward:**
```bash
kubectl port-forward -n monitoring svc/grafana 3000:3000
```
Then access: http://localhost:3000

**Using LoadBalancer (External):**
```bash
# Get the external IP
kubectl get svc grafana-external -n monitoring

# Access Grafana at: http://<EXTERNAL-IP>:3000
```

**Default Credentials:**
- Username: `admin`
- Password: `admin123`

⚠️ **IMPORTANT**: Change the default password immediately after first login!

## Configuration

### Prometheus Configuration

The Prometheus configuration is stored in `prometheus-config.yaml` and includes:
- Scraping of Kubernetes API server
- Node metrics collection
- cAdvisor metrics for container monitoring
- Service endpoint discovery
- Pod discovery

To update the configuration:
1. Edit `prometheus-config.yaml`
2. Apply changes: `kubectl apply -f prometheus-config.yaml`
3. Restart Prometheus: `kubectl rollout restart deployment/prometheus -n monitoring`

### Grafana Dashboards

After logging into Grafana, you can import popular Kubernetes dashboards:

1. **Kubernetes Cluster Monitoring**: Dashboard ID `7249`
2. **Kubernetes Pod Monitoring**: Dashboard ID `6417`
3. **Node Exporter Full**: Dashboard ID `1860`
4. **Kubernetes Cluster (Prometheus)**: Dashboard ID `6417`

To import:
1. Go to Dashboards → Import
2. Enter the dashboard ID
3. Select Prometheus as the datasource
4. Click Import

## Storage Configuration

Both Prometheus and Grafana use persistent storage:
- **Prometheus**: 50Gi (configurable in `prometheus-pvc.yaml`)
- **Grafana**: 10Gi (configurable in `grafana-pvc.yaml`)
- **Storage Class**: gp2 (AWS EBS)

To change storage size, edit the respective PVC files before deployment.

## Resource Limits

### Prometheus
- Memory Request: 1Gi
- Memory Limit: 2Gi
- CPU Request: 500m
- CPU Limit: 1000m
- Data Retention: 15 days

### Grafana
- Memory Request: 512Mi
- Memory Limit: 1Gi
- CPU Request: 250m
- CPU Limit: 500m

Adjust these values in the deployment files based on your cluster size and monitoring needs.

## Monitoring Targets

Prometheus is configured to scrape metrics from:
1. **Kubernetes API Server**: Cluster-level metrics
2. **Nodes**: Node-level metrics
3. **cAdvisor**: Container metrics
4. **Service Endpoints**: Services with annotation `prometheus.io/scrape: "true"`
5. **Pods**: Pods with annotation `prometheus.io/scrape: "true"`

### Annotate Your Services for Monitoring

To enable monitoring for your services, add these annotations:

```yaml
metadata:
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "8080"
    prometheus.io/path: "/metrics"
```

## Troubleshooting

### Prometheus Not Starting

```bash
# Check logs
kubectl logs -n monitoring deployment/prometheus

# Check configuration
kubectl describe configmap prometheus-config -n monitoring
```

### Grafana Not Showing Data

1. Check if Prometheus is accessible:
   ```bash
   kubectl exec -it -n monitoring deployment/grafana -- curl http://prometheus:9090/-/healthy
   ```

2. Verify datasource configuration:
   ```bash
   kubectl describe configmap grafana-datasources -n monitoring
   ```

### Persistent Volume Issues

```bash
# Check PVC status
kubectl get pvc -n monitoring
kubectl describe pvc prometheus-storage -n monitoring
kubectl describe pvc grafana-storage -n monitoring

# Check storage class
kubectl get storageclass
```

## Security Considerations

1. **Change default passwords**: Update Grafana admin password
2. **Use Ingress with TLS**: For production, use Ingress instead of LoadBalancer
3. **Enable authentication**: Configure OAuth or LDAP for Grafana
4. **Network policies**: Implement network policies to restrict access
5. **RBAC**: Prometheus ServiceAccount has minimal required permissions

## Cleanup

To remove all monitoring components:

```bash
kubectl delete -f grafana-deployment.yaml
kubectl delete -f grafana-pvc.yaml
kubectl delete -f grafana-config.yaml
kubectl delete -f prometheus-deployment.yaml
kubectl delete -f prometheus-pvc.yaml
kubectl delete -f prometheus-config.yaml
kubectl delete -f prometheus-rbac.yaml
kubectl delete -f namespace.yaml
```

⚠️ **Warning**: This will delete all monitoring data stored in persistent volumes!

## Additional Resources

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [Kubernetes Monitoring Best Practices](https://kubernetes.io/docs/tasks/debug-application-cluster/resource-usage-monitoring/)
- [AWS EKS Best Practices for Monitoring](https://aws.github.io/aws-eks-best-practices/)

## Support and Customization

For customization needs:
- Edit scrape intervals in `prometheus-config.yaml`
- Adjust retention period in `prometheus-deployment.yaml`
- Add custom recording rules to Prometheus
- Configure alerting rules and Alertmanager
- Set up custom Grafana dashboards
