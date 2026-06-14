#!/bin/bash
# jenkins/scripts/deploy.sh - Deploy script for RailConnect
# Called by Jenkinsfile during CD pipeline
# Deploys Docker image to Kubernetes cluster

set -e

CLUSTER_NAME="${1:-railconnect-prod}"
ENVIRONMENT="${2:-production}"
NAMESPACE="railconnect-${ENVIRONMENT}"
IMAGE="${3:-}"
REGION="ap-south-1"
TIMEOUT="10m"

echo "╔════════════════════════════════════════════════════════╗"
echo "║  RailConnect Kubernetes Deployment Script              ║"
echo "║  Cluster: $CLUSTER_NAME                                ║"
echo "║  Environment: $ENVIRONMENT                             ║"
echo "║  Namespace: $NAMESPACE                                 ║"
echo "║  Image: $IMAGE                                         ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""

# Validate inputs
if [ -z "$IMAGE" ]; then
    echo "❌ ERROR: Docker image not specified"
    echo "Usage: ./deploy.sh <cluster-name> <environment> <image>"
    exit 1
fi

# Step 1: Configure kubectl
echo "[1/5] Configuring kubectl for cluster: $CLUSTER_NAME..."
aws eks update-kubeconfig \
    --region "$REGION" \
    --name "$CLUSTER_NAME" \
    --alias "$CLUSTER_NAME"

# Verify cluster connectivity
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ ERROR: Cannot connect to Kubernetes cluster"
    exit 1
fi

echo "✅ Cluster connected"

# Step 2: Verify namespace exists
echo "[2/5] Verifying namespace: $NAMESPACE..."
if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
    echo "Creating namespace: $NAMESPACE"
    kubectl create namespace "$NAMESPACE"
fi

echo "✅ Namespace ready"

# Step 3: Update deployment image
echo "[3/5] Updating deployment image to: $IMAGE..."
kubectl set image deployment/railconnect-app \
    railconnect-app="$IMAGE" \
    -n "$NAMESPACE" \
    --record

echo "✅ Deployment image updated"

# Step 4: Wait for rollout
echo "[4/5] Waiting for rollout (timeout: $TIMEOUT)..."
kubectl rollout status deployment/railconnect-app \
    -n "$NAMESPACE" \
    --timeout="$TIMEOUT"

echo "✅ Rollout successful"

# Step 5: Verify health
echo "[5/5] Verifying deployment health..."
sleep 30

READY_PODS=$(kubectl get deployment railconnect-app -n "$NAMESPACE" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
DESIRED_PODS=$(kubectl get deployment railconnect-app -n "$NAMESPACE" -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
AVAILABLE_PODS=$(kubectl get deployment railconnect-app -n "$NAMESPACE" -o jsonpath='{.status.availableReplicas}' 2>/dev/null || echo "0")

echo "Pod Status:"
echo "  Ready: $READY_PODS/$DESIRED_PODS"
echo "  Available: $AVAILABLE_PODS/$DESIRED_PODS"

if [ "$READY_PODS" != "$DESIRED_PODS" ]; then
    echo "⚠️  WARNING: Not all pods are ready yet, but deployment is proceeding"
    # Get more details
    echo ""
    echo "Pod Details:"
    kubectl get pods -n "$NAMESPACE" -l app=railconnect-app
    echo ""
    echo "Recent Events:"
    kubectl describe deployment railconnect-app -n "$NAMESPACE" | tail -20
fi

# Get service endpoint
echo ""
echo "╔════════════════════════════════════════════════════════╗"
echo "║  DEPLOYMENT SUCCESSFUL                                ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""
echo "Service Access:"

SERVICE_IP=$(kubectl get svc railconnect-app -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "pending")

if [ "$SERVICE_IP" = "pending" ]; then
    SERVICE_IP=$(kubectl get svc railconnect-app -n "$NAMESPACE" -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
    echo "  Cluster IP: $SERVICE_IP:80"
    echo "  (Use kubectl port-forward to access externally)"
else
    echo "  Load Balancer: $SERVICE_IP:80"
fi

echo ""
echo "Next Steps:"
echo "  • Check pod status: kubectl get pods -n $NAMESPACE -w"
echo "  • View logs: kubectl logs -n $NAMESPACE -l app=railconnect-app -f"
echo "  • Describe deployment: kubectl describe deployment railconnect-app -n $NAMESPACE"
echo ""

exit 0
