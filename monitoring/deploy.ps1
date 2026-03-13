# PowerShell Deployment Script for Prometheus and Grafana monitoring stack
# Usage: .\deploy.ps1 [apply|delete|status]

param(
    [Parameter(Position=0)]
    [ValidateSet("apply", "delete", "status", "help")]
    [string]$Command = "apply"
)

$ErrorActionPreference = "Stop"
$namespace = "monitoring"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Write-Error-Custom {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Test-Kubectl {
    try {
        $null = kubectl version --client
        Write-Info "kubectl found"
        return $true
    }
    catch {
        Write-Error-Custom "kubectl not found. Please install kubectl first."
        return $false
    }
}

function Test-ClusterConnection {
    try {
        $null = kubectl cluster-info 2>$null
        $context = kubectl config current-context
        Write-Info "Connected to cluster: $context"
        return $true
    }
    catch {
        Write-Error-Custom "Cannot connect to Kubernetes cluster. Please check your kubeconfig."
        return $false
    }
}

function Deploy-MonitoringStack {
    Write-Info "Starting deployment of monitoring stack..."
    
    Write-Info "Creating namespace..."
    kubectl apply -f "$scriptDir\namespace.yaml"
    
    Write-Info "Deploying Prometheus RBAC..."
    kubectl apply -f "$scriptDir\prometheus-rbac.yaml"
    
    Write-Info "Deploying Prometheus configuration..."
    kubectl apply -f "$scriptDir\prometheus-config.yaml"
    
    Write-Info "Creating Prometheus PVC..."
    kubectl apply -f "$scriptDir\prometheus-pvc.yaml"
    
    Write-Info "Deploying Prometheus..."
    kubectl apply -f "$scriptDir\prometheus-deployment.yaml"
    
    Write-Info "Deploying Grafana configuration..."
    kubectl apply -f "$scriptDir\grafana-config.yaml"
    
    Write-Info "Creating Grafana PVC..."
    kubectl apply -f "$scriptDir\grafana-pvc.yaml"
    
    Write-Info "Deploying Grafana..."
    kubectl apply -f "$scriptDir\grafana-deployment.yaml"
    
    Write-Info "Deployment complete! Waiting for pods to be ready..."
    
    # Wait for deployments
    try {
        kubectl wait --for=condition=available --timeout=300s deployment/prometheus -n $namespace
    }
    catch {
        Write-Warn "Prometheus deployment timeout"
    }
    
    try {
        kubectl wait --for=condition=available --timeout=300s deployment/grafana -n $namespace
    }
    catch {
        Write-Warn "Grafana deployment timeout"
    }
    
    Write-Host ""
    Write-Info "Monitoring stack deployed successfully!"
    Write-Host ""
    Show-Status
}

function Remove-MonitoringStack {
    Write-Warn "This will delete all monitoring components and data. Are you sure? (yes/no)"
    $response = Read-Host
    
    if ($response -ne "yes") {
        Write-Info "Deletion cancelled."
        return
    }
    
    Write-Info "Deleting monitoring stack..."
    
    kubectl delete -f "$scriptDir\grafana-deployment.yaml" --ignore-not-found=true
    kubectl delete -f "$scriptDir\grafana-pvc.yaml" --ignore-not-found=true
    kubectl delete -f "$scriptDir\grafana-config.yaml" --ignore-not-found=true
    kubectl delete -f "$scriptDir\prometheus-deployment.yaml" --ignore-not-found=true
    kubectl delete -f "$scriptDir\prometheus-pvc.yaml" --ignore-not-found=true
    kubectl delete -f "$scriptDir\prometheus-config.yaml" --ignore-not-found=true
    kubectl delete -f "$scriptDir\prometheus-rbac.yaml" --ignore-not-found=true
    kubectl delete -f "$scriptDir\namespace.yaml" --ignore-not-found=true
    
    Write-Info "Monitoring stack deleted successfully!"
}

function Show-Status {
    Write-Info "Monitoring stack status:"
    Write-Host ""
    
    Write-Host "=== Pods ===" -ForegroundColor Cyan
    kubectl get pods -n $namespace
    Write-Host ""
    
    Write-Host "=== Services ===" -ForegroundColor Cyan
    kubectl get svc -n $namespace
    Write-Host ""
    
    Write-Host "=== Persistent Volume Claims ===" -ForegroundColor Cyan
    kubectl get pvc -n $namespace
    Write-Host ""
    
    # Get external IPs if available
    try {
        $prometheusIP = kubectl get svc prometheus-external -n $namespace -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>$null
        if (-not $prometheusIP) { $prometheusIP = "pending" }
    }
    catch {
        $prometheusIP = "pending"
    }
    
    try {
        $grafanaIP = kubectl get svc grafana-external -n $namespace -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>$null
        if (-not $grafanaIP) { $grafanaIP = "pending" }
    }
    catch {
        $grafanaIP = "pending"
    }
    
    Write-Host "=== Access Information ===" -ForegroundColor Cyan
    Write-Host "Prometheus External URL: http://${prometheusIP}:9090"
    Write-Host "Grafana External URL: http://${grafanaIP}:3000"
    Write-Host ""
    Write-Host "Or use port-forward:"
    Write-Host "  Prometheus: kubectl port-forward -n monitoring svc/prometheus 9090:9090"
    Write-Host "  Grafana:    kubectl port-forward -n monitoring svc/grafana 3000:3000"
    Write-Host ""
    Write-Host "Grafana Credentials:"
    Write-Host "  Username: admin"
    Write-Host "  Password: admin123"
}

function Show-Usage {
    Write-Host "Usage: .\deploy.ps1 [command]"
    Write-Host ""
    Write-Host "Commands:"
    Write-Host "  apply    - Deploy the monitoring stack"
    Write-Host "  delete   - Delete the monitoring stack"
    Write-Host "  status   - Show status of monitoring components"
    Write-Host "  help     - Show this help message"
    Write-Host ""
}

# Main script execution
if (-not (Test-Kubectl)) {
    exit 1
}

if (-not (Test-ClusterConnection)) {
    exit 1
}

switch ($Command) {
    "apply" {
        Deploy-MonitoringStack
    }
    "delete" {
        Remove-MonitoringStack
    }
    "status" {
        Show-Status
    }
    "help" {
        Show-Usage
    }
    default {
        Write-Error-Custom "Unknown command: $Command"
        Show-Usage
        exit 1
    }
}
