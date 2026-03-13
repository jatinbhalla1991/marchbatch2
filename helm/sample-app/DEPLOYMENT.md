# Deployment Guide

Complete guide for deploying the sample application to Amazon EKS.

## Prerequisites Setup

### 1. Install Required Tools

```bash
# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Verify installation
helm version

# Install AWS CLI (if not already installed)
# Windows: Download from AWS website
# macOS: brew install awscli
# Linux: sudo apt-get install awscli

# Configure AWS credentials
aws configure
```

### 2. Verify EKS Cluster Access

```bash
# Update kubeconfig
aws eks update-kubeconfig --name <cluster-name> --region <region>

# Verify access
kubectl get nodes
kubectl cluster-info
```

### 3. Install AWS Load Balancer Controller (for Ingress)

```bash
# Create IAM policy
curl -o iam_policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json

aws iam create-policy \
  --policy-name AWSLoadBalancerControllerIAMPolicy \
  --policy-document file://iam_policy.json

# Create IRSA
eksctl create iamserviceaccount \
  --cluster=<cluster-name> \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --attach-policy-arn=arn:aws:iam::<account-id>:policy/AWSLoadBalancerControllerIAMPolicy \
  --override-existing-serviceaccounts \
  --approve

# Install controller via Helm
helm repo add eks https://aws.github.io/eks-charts
helm repo update

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=<cluster-name> \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller
```

### 4. Install Metrics Server (for HPA)

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Verify
kubectl get deployment metrics-server -n kube-system
```

## Building and Pushing Docker Image

### Option 1: Using ECR

```bash
# Set variables
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export AWS_REGION=us-east-1
export ECR_REPO=sample-app
export IMAGE_TAG=1.0.0

# Create ECR repository
aws ecr create-repository --repository-name $ECR_REPO --region $AWS_REGION

# Login to ECR
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

# Build image
cd helm/sample-app/app
docker build -t $ECR_REPO:$IMAGE_TAG .

# Tag image
docker tag $ECR_REPO:$IMAGE_TAG $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO:$IMAGE_TAG

# Push image
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO:$IMAGE_TAG

# Update values.yaml
cd ../
cat > custom-values.yaml <<EOF
image:
  repository: $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO
  tag: "$IMAGE_TAG"
EOF
```

### Option 2: Using Docker Hub

```bash
# Login to Docker Hub
docker login

# Build and tag
docker build -t <your-dockerhub-username>/sample-app:1.0.0 .
docker push <your-dockerhub-username>/sample-app:1.0.0

# Update values
cat > custom-values.yaml <<EOF
image:
  repository: <your-dockerhub-username>/sample-app
  tag: "1.0.0"
EOF
```

## Deployment Scenarios

### Scenario 1: Development Deployment

```bash
# Create namespace
kubectl create namespace dev

# Install with dev values
helm install sample-app ./helm/sample-app \
  -f ./helm/sample-app/values-dev.yaml \
  -f custom-values.yaml \
  -n dev

# Verify
kubectl get all -n dev -l app.kubernetes.io/name=sample-app

# Access via port-forward
kubectl port-forward -n dev svc/sample-app 8080:80

# Test
curl http://localhost:8080/health
```

### Scenario 2: Production Deployment

```bash
# Create namespace
kubectl create namespace production

# Install with prod values
helm install sample-app ./helm/sample-app \
  -f ./helm/sample-app/values-prod.yaml \
  -f custom-values.yaml \
  -n production

# Verify
kubectl get all -n production -l app.kubernetes.io/name=sample-app

# Check HPA
kubectl get hpa -n production

# Check ingress
kubectl get ingress -n production
```

### Scenario 3: Custom Configuration

```bash
# Create custom values file
cat > my-values.yaml <<EOF
replicaCount: 3

resources:
  limits:
    cpu: 1000m
    memory: 1Gi
  requests:
    cpu: 500m
    memory: 512Mi

ingress:
  enabled: true
  hosts:
    - host: my-app.example.com
      paths:
        - path: /
          pathType: Prefix

autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 15
  targetCPUUtilizationPercentage: 60
EOF

# Install
helm install sample-app ./helm/sample-app \
  -f my-values.yaml \
  -f custom-values.yaml \
  -n production
```

## Post-Deployment Verification

### 1. Check All Resources

```bash
# Check pods
kubectl get pods -l app.kubernetes.io/name=sample-app

# Check service
kubectl get svc -l app.kubernetes.io/name=sample-app

# Check deployment
kubectl get deployment -l app.kubernetes.io/name=sample-app

# Check HPA
kubectl get hpa -l app.kubernetes.io/name=sample-app

# Check ingress
kubectl get ingress -l app.kubernetes.io/name=sample-app
```

### 2. Check Pod Health

```bash
# Describe pod
kubectl describe pod -l app.kubernetes.io/name=sample-app | grep -A 10 "Conditions"

# Check logs
kubectl logs -l app.kubernetes.io/name=sample-app --tail=50

# Execute commands in pod
kubectl exec -it deployment/sample-app -- /bin/sh
```

### 3. Test Endpoints

```bash
# Port forward
kubectl port-forward svc/sample-app 8080:80

# Test health
curl http://localhost:8080/health

# Test ready
curl http://localhost:8080/ready

# Test metrics
curl http://localhost:8080/metrics

# Test API
curl http://localhost:8080/api/users
```

### 4. Load Testing

```bash
# Generate load to test autoscaling
kubectl run -it --rm load-generator --image=busybox -- /bin/sh

# Inside the pod
while true; do wget -q -O- http://sample-app/api/users; done

# Watch HPA in another terminal
kubectl get hpa -w
```

## Monitoring Integration

### With Existing Prometheus

If you already have Prometheus running (like in the monitoring namespace):

```bash
# Ensure service has Prometheus annotations
kubectl get svc sample-app -o yaml | grep prometheus

# Check if Prometheus is scraping
kubectl port-forward -n monitoring svc/prometheus 9090:9090

# Open http://localhost:9090/targets and look for sample-app
```

### With Prometheus Operator

```bash
# Enable ServiceMonitor in values
cat > servicemonitor-values.yaml <<EOF
serviceMonitor:
  enabled: true
  interval: 15s
  scrapeTimeout: 10s
  labels:
    release: prometheus
EOF

# Upgrade deployment
helm upgrade sample-app ./helm/sample-app \
  -f servicemonitor-values.yaml
```

## Upgrading the Application

### Rolling Update

```bash
# Update image tag in custom-values.yaml
cat > custom-values.yaml <<EOF
image:
  repository: $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO
  tag: "1.1.0"
EOF

# Upgrade
helm upgrade sample-app ./helm/sample-app \
  -f custom-values.yaml

# Watch rollout
kubectl rollout status deployment/sample-app

# Check history
helm history sample-app
```

### Rollback

```bash
# Rollback to previous version
helm rollback sample-app

# Rollback to specific revision
helm rollback sample-app 2

# Check status
kubectl get pods -l app.kubernetes.io/name=sample-app
```

## Troubleshooting

### Pods in CrashLoopBackOff

```bash
# Check logs
kubectl logs -l app.kubernetes.io/name=sample-app --previous

# Check events
kubectl get events --sort-by='.lastTimestamp' | grep sample-app

# Describe pod
kubectl describe pod -l app.kubernetes.io/name=sample-app
```

### ImagePullBackOff

```bash
# Check if image exists
aws ecr describe-images --repository-name sample-app

# Verify node permissions
# Ensure EKS node IAM role has ecr:GetAuthorizationToken, ecr:BatchGetImage, ecr:GetDownloadUrlForLayer

# Check image pull secret (if using private registry)
kubectl get secrets

# Test image pull manually
docker pull <image-url>
```

### HPA Not Scaling

```bash
# Check metrics server
kubectl get apiservice v1beta1.metrics.k8s.io -o yaml

# Check HPA status
kubectl describe hpa sample-app

# Check current metrics
kubectl top pods -l app.kubernetes.io/name=sample-app

# Generate load to trigger scaling
kubectl run -it --rm load-generator --image=busybox -- /bin/sh
while true; do wget -q -O- http://sample-app/api/users; done
```

### Ingress Not Working

```bash
# Check ALB controller logs
kubectl logs -n kube-system deployment/aws-load-balancer-controller

# Check ingress status
kubectl describe ingress sample-app

# Verify AWS resources created
aws elbv2 describe-load-balancers
aws elbv2 describe-target-groups

# Check security groups
# Ensure ALB security group allows inbound traffic
```

## Cleanup

```bash
# Uninstall Helm release
helm uninstall sample-app

# Delete namespace (if needed)
kubectl delete namespace production

# Delete ECR repository
aws ecr delete-repository --repository-name sample-app --force

# Delete load balancer controller (if not needed)
helm uninstall aws-load-balancer-controller -n kube-system
```

## Best Practices

1. **Version Control**: Always version your Helm values files
2. **CI/CD Integration**: Automate builds and deployments
3. **Resource Limits**: Always set resource requests and limits
4. **Health Checks**: Use proper liveness and readiness probes
5. **Monitoring**: Enable ServiceMonitor for better observability
6. **Security**: Use non-root containers and security contexts
7. **High Availability**: Use multiple replicas and pod anti-affinity
8. **Autoscaling**: Enable HPA for dynamic scaling
9. **Ingress**: Use ALB for production traffic
10. **Backup**: Keep Helm values and configs in version control
