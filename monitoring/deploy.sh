#!/bin/bash

# Deployment script for Prometheus and Grafana monitoring stack
# Usage: ./deploy.sh [apply|delete|status]

set -e

NAMESPACE="monitoring"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

function print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

function print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

function print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

function check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl not found. Please install kubectl first."
        exit 1
    fi
    print_info "kubectl found: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
}

function check_cluster_connection() {
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster. Please check your kubeconfig."
        exit 1
    fi
    print_info "Connected to cluster: $(kubectl config current-context)"
}

function deploy() {
    print_info "Starting deployment of monitoring stack..."
    
    # Deploy in order
    print_info "Creating namespace..."
    kubectl apply -f "$SCRIPT_DIR/namespace.yaml"
    
    print_info "Deploying Prometheus RBAC..."
    kubectl apply -f "$SCRIPT_DIR/prometheus-rbac.yaml"
    
    print_info "Deploying Prometheus configuration..."
    kubectl apply -f "$SCRIPT_DIR/prometheus-config.yaml"
    
    print_info "Creating Prometheus PVC..."
    kubectl apply -f "$SCRIPT_DIR/prometheus-pvc.yaml"
    
    print_info "Deploying Prometheus..."
    kubectl apply -f "$SCRIPT_DIR/prometheus-deployment.yaml"
    
    print_info "Deploying Grafana configuration..."
    kubectl apply -f "$SCRIPT_DIR/grafana-config.yaml"
    
    print_info "Creating Grafana PVC..."
    kubectl apply -f "$SCRIPT_DIR/grafana-pvc.yaml"
    
    print_info "Deploying Grafana..."
    kubectl apply -f "$SCRIPT_DIR/grafana-deployment.yaml"
    
    print_info "Deployment complete! Waiting for pods to be ready..."
    
    # Wait for deployments
    kubectl wait --for=condition=available --timeout=300s deployment/prometheus -n $NAMESPACE || print_warn "Prometheus deployment timeout"
    kubectl wait --for=condition=available --timeout=300s deployment/grafana -n $NAMESPACE || print_warn "Grafana deployment timeout"
    
    echo ""
    print_info "Monitoring stack deployed successfully!"
    echo ""
    show_status
}

function delete() {
    print_warn "This will delete all monitoring components and data. Are you sure? (yes/no)"
    read -r response
    if [[ "$response" != "yes" ]]; then
        print_info "Deletion cancelled."
        exit 0
    fi
    
    print_info "Deleting monitoring stack..."
    
    kubectl delete -f "$SCRIPT_DIR/grafana-deployment.yaml" --ignore-not-found=true
    kubectl delete -f "$SCRIPT_DIR/grafana-pvc.yaml" --ignore-not-found=true
    kubectl delete -f "$SCRIPT_DIR/grafana-config.yaml" --ignore-not-found=true
    kubectl delete -f "$SCRIPT_DIR/prometheus-deployment.yaml" --ignore-not-found=true
    kubectl delete -f "$SCRIPT_DIR/prometheus-pvc.yaml" --ignore-not-found=true
    kubectl delete -f "$SCRIPT_DIR/prometheus-config.yaml" --ignore-not-found=true
    kubectl delete -f "$SCRIPT_DIR/prometheus-rbac.yaml" --ignore-not-found=true
    kubectl delete -f "$SCRIPT_DIR/namespace.yaml" --ignore-not-found=true
    
    print_info "Monitoring stack deleted successfully!"
}

function show_status() {
    print_info "Monitoring stack status:"
    echo ""
    
    echo "=== Pods ==="
    kubectl get pods -n $NAMESPACE
    echo ""
    
    echo "=== Services ==="
    kubectl get svc -n $NAMESPACE
    echo ""
    
    echo "=== Persistent Volume Claims ==="
    kubectl get pvc -n $NAMESPACE
    echo ""
    
    # Get external IPs if available
    PROMETHEUS_IP=$(kubectl get svc prometheus-external -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "pending")
    GRAFANA_IP=$(kubectl get svc grafana-external -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "pending")
    
    echo "=== Access Information ==="
    echo "Prometheus External URL: http://$PROMETHEUS_IP:9090"
    echo "Grafana External URL: http://$GRAFANA_IP:3000"
    echo ""
    echo "Or use port-forward:"
    echo "  Prometheus: kubectl port-forward -n monitoring svc/prometheus 9090:9090"
    echo "  Grafana:    kubectl port-forward -n monitoring svc/grafana 3000:3000"
    echo ""
    echo "Grafana Credentials:"
    echo "  Username: admin"
    echo "  Password: admin123"
}

function show_usage() {
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  apply    - Deploy the monitoring stack"
    echo "  delete   - Delete the monitoring stack"
    echo "  status   - Show status of monitoring components"
    echo "  help     - Show this help message"
    echo ""
}

# Main script
check_kubectl
check_cluster_connection

case "${1:-apply}" in
    apply)
        deploy
        ;;
    delete)
        delete
        ;;
    status)
        show_status
        ;;
    help)
        show_usage
        ;;
    *)
        print_error "Unknown command: $1"
        show_usage
        exit 1
        ;;
esac
