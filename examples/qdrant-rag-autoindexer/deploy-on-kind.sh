#!/bin/bash

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
KIND_CLUSTER_NAME="kaito-ragengine-cluster"
KIND_CONFIG="kind-cluster-config.yaml"
RAGENGINE_CHART="oci://ghcr.io/kaito-project/charts/ragengine:0.9.3-qdrant.2"
AUTOINDEXER_CHART="oci://ghcr.io/kaito-project/charts/autoindexer:0.0.0-dev.2"
NAMESPACE_RAGENGINE="kaito-ragengine" 
NAMESPACE_AUTOINDEXER="kaito-autoindexer"

# Function to print colored output
log() {
    local color=$1
    shift
    echo -e "${color}[$(date '+%Y-%m-%d %H:%M:%S')] $*${NC}"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check prerequisites
check_prerequisites() {
    log $BLUE "Checking prerequisites..."
    
    local missing_tools=()
    
    if ! command_exists kind; then
        missing_tools+=("kind")
    fi
    
    if ! command_exists kubectl; then
        missing_tools+=("kubectl")  
    fi
    
    if ! command_exists helm; then
        missing_tools+=("helm")
    fi
    
    if ! command_exists docker; then
        missing_tools+=("docker")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        log $RED "Missing required tools: ${missing_tools[*]}"
        log $YELLOW "Please install the missing tools:"
        for tool in "${missing_tools[@]}"; do
            case $tool in
                "kind")
                    log $YELLOW "  kind: https://kind.sigs.k8s.io/docs/user/quick-start/"
                    ;;
                "kubectl")
                    log $YELLOW "  kubectl: https://kubernetes.io/docs/tasks/tools/"
                    ;;
                "helm")
                    log $YELLOW "  helm: https://helm.sh/docs/intro/install/"
                    ;;
                "docker")
                    log $YELLOW "  docker: https://docs.docker.com/get-docker/"
                    ;;
            esac
        done
        exit 1
    fi
    
    # Check if Docker is running
    if ! docker info >/dev/null 2>&1; then
        log $RED "Docker is not running. Please start Docker and try again."
        exit 1
    fi
    
    log $GREEN "All prerequisites satisfied"
}

# Function to create kind cluster
create_kind_cluster() {
    log $BLUE "Setting up kind cluster..."
    
    # Check if cluster already exists
    if kind get clusters | grep -q "^${KIND_CLUSTER_NAME}$"; then
        log $YELLOW "Kind cluster '$KIND_CLUSTER_NAME' already exists"
        read -p "Do you want to delete and recreate it? (y/n): " -r
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log $BLUE "Deleting existing cluster..."
            kind delete cluster --name "$KIND_CLUSTER_NAME"
        else
            log $BLUE "Using existing cluster"
            kubectl cluster-info --context "kind-${KIND_CLUSTER_NAME}"
            return 0
        fi
    fi
    
    # Create storage directory for hostPath volumes
    log $BLUE "Creating storage directory for kind..."
    mkdir -p /tmp/kind-storage
    
    # Create kind cluster
    log $BLUE "Creating kind cluster with config..."
    if ! kind create cluster --name "$KIND_CLUSTER_NAME" --config "$KIND_CONFIG" --wait 300s; then
        log $RED "Failed to create kind cluster"
        exit 1
    fi
    
    # Install local-path-provisioner for dynamic PV provisioning
    log $BLUE "Installing local-path-provisioner..."
    kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.28/deploy/local-path-storage.yaml
    
    # Wait for local-path-provisioner to be ready
    kubectl wait --for=condition=available --timeout=300s deployment/local-path-provisioner -n local-path-storage
    
    # Set local-path as default storage class
    kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
    
    log $GREEN "Kind cluster created successfully"
    kubectl cluster-info --context "kind-${KIND_CLUSTER_NAME}"
}

# Function to install Karpenter CRDs only
install_karpenter() {
    log $BLUE "Installing Karpenter CRDs (Custom Resource Definitions)..."
    log $YELLOW "Note: Installing CRDs only - no controller (perfect for kind clusters)"
    
    # Create karpenter namespace for consistency
    kubectl create namespace karpenter --dry-run=client -o yaml | kubectl apply -f -
    
    # Try to extract and install CRDs from Helm chart
    log $BLUE "Extracting Karpenter CRDs from Helm chart..."
    if helm template karpenter-crds oci://public.ecr.aws/karpenter/karpenter \
        --version 1.8.1 \
        --include-crds \
        --no-hooks 2>/dev/null | \
        kubectl apply -f - --dry-run=client >/dev/null 2>&1; then
        
        log $GREEN "Installing CRDs via Helm template..."
        helm template karpenter-crds oci://public.ecr.aws/karpenter/karpenter \
            --version 1.8.1 \
            --include-crds \
            --no-hooks | \
            kubectl apply -f -
    else
        log $YELLOW "Helm CRD extraction failed, trying direct CRD installation..."
        
        # Fallback: Install CRDs from GitHub releases
        kubectl apply -f https://raw.githubusercontent.com/aws/karpenter-provider-aws/v1.8.1/pkg/apis/crds/karpenter.sh_nodepools.yaml 2>/dev/null || log $YELLOW "Failed to install NodePool CRD"
        kubectl apply -f https://raw.githubusercontent.com/aws/karpenter-provider-aws/v1.8.1/pkg/apis/crds/karpenter.sh_nodeclaims.yaml 2>/dev/null || log $YELLOW "Failed to install NodeClaim CRD"
        kubectl apply -f https://raw.githubusercontent.com/aws/karpenter-provider-aws/v1.8.1/pkg/apis/crds/karpenter.k8s.aws_ec2nodeclasses.yaml 2>/dev/null || log $YELLOW "AWS EC2NodeClass CRD not installed (not needed for kind)"
    fi
    
    # Verify CRD installation
    if kubectl get crd 2>/dev/null | grep -q karpenter; then
        log $GREEN "✅ Karpenter CRDs installed successfully!"
        log $BLUE "Installed CRDs:"
        kubectl get crd -o name 2>/dev/null | grep karpenter | sed 's/customresourcedefinition.apiextensions.k8s.io\//  - /' || true
    else
        log $YELLOW "⚠️  Karpenter CRDs installation may have failed, continuing anyway..."
    fi
    
    log $GREEN "Karpenter CRDs available (no controller running - perfect for kind!)"
}

# Function to install KAITO CRDs
install_kaito_crds() {
    log $BLUE "Installing KAITO CRDs..."
    
    # Install KAITO CRDs - this might be handled by the Helm charts
    # For now, let's proceed with the Helm charts which should include the CRDs
    log $YELLOW "KAITO CRDs will be installed by the Helm charts"
}

# Function to deploy the stack (reusing logic from main script)
deploy_stack() {
    log $BLUE "Deploying KAITO RAGEngine + AutoIndexer stack on kind..."
    
    # Create namespaces
    log $BLUE "Creating namespaces..."
    kubectl create namespace "$NAMESPACE_RAGENGINE" --dry-run=client -o yaml | kubectl apply -f -
    kubectl create namespace "$NAMESPACE_AUTOINDEXER" --dry-run=client -o yaml | kubectl apply -f -
    
    # Install RAGEngine Helm chart
    log $BLUE "Installing RAGEngine Helm chart..."
    helm upgrade --install ragengine "$RAGENGINE_CHART" \
        --namespace "$NAMESPACE_RAGENGINE" \
        --wait \
        --wait-for-jobs \
        --timeout 10m
    
    # Install AutoIndexer Helm chart
    log $BLUE "Installing AutoIndexer Helm chart..."
    helm upgrade --install autoindexer "$AUTOINDEXER_CHART" \
        --namespace "$NAMESPACE_AUTOINDEXER" \
        --wait \
        --wait-for-jobs \
        --timeout 10m
    
    # Deploy Qdrant components
    log $BLUE "Deploying Qdrant components..."
    # kubectl apply -f qdrant-pvc.yaml
    kubectl apply -f qdrant-service.yaml  
    kubectl apply -f qdrant.yaml
    
    # Wait for Qdrant
    log $BLUE "Waiting for Qdrant to be ready..."
    kubectl wait --for=condition=available --timeout=600s deployment/qdrant -n default
    
    # Deploy RAGEngine CRD
    log $BLUE "Deploying RAGEngine custom resource..."

    kubectl apply -f ragengine.yaml
    
    # Wait for RAGEngine (improved check)
    log $BLUE "Waiting for RAGEngine to be created..."
    kubectl wait --for=condition=ServiceReady --timeout=300s ragengine/ragengine 2>/dev/null || {
        log $YELLOW "ServiceReady condition not available yet, checking if resource exists..."
        kubectl get ragengine/ragengine -o wide || exit 1
    }
    
    # Deploy AutoIndexer CRDs
    log $BLUE "Deploying AutoIndexer custom resources..."
    kubectl apply -f kaito-code-autoindexer.yaml
    kubectl apply -f kaito-docs-autoindexer.yaml
    
    # Wait for AutoIndexers to be scheduled
    log $BLUE "Waiting for AutoIndexers to be ready..."
    kubectl wait --for=condition=ResourceReady --timeout=300s autoindexer/kaito-code-autoindexer
    kubectl wait --for=condition=ResourceReady --timeout=300s autoindexer/kaito-docs-autoindexer
    
    # Deploy external service for RAGEngine
    log $BLUE "Deploying RAGEngine external service..."
    kubectl apply -f ragengine-external.yaml
    
    log $GREEN "Stack deployment completed!"
}

# Function to display post-deployment info
show_cluster_info() {
    log $GREEN "=== Kind Cluster Information ==="
    log $BLUE "Cluster name: $KIND_CLUSTER_NAME"
    log $BLUE "Kubectl context: kind-${KIND_CLUSTER_NAME}"
    
    echo ""
    log $GREEN "=== Deployment Status ==="
    log $BLUE "Checking RAGEngine status:"
    kubectl get ragengines -o wide
    
    echo ""
    log $BLUE "Checking AutoIndexer status:" 
    kubectl get autoindexers -o wide
    
    echo ""
    log $BLUE "Checking service status:"
    log $BLUE "Internal services:"
    kubectl get svc ragengine qdrant -o wide 2>/dev/null || echo "  Services not yet ready"
    echo ""
    log $BLUE "External services:"
    kubectl get svc ragengine-external -o wide 2>/dev/null || echo "  External service not yet ready"
    
    echo ""
    log $BLUE "Checking pod status:"
    kubectl get pods -A | grep -E "(ragengine|autoindexer|qdrant|karpenter)"
    
    echo ""
    log $GREEN "=== Useful Commands ==="
    log $BLUE "Check cluster status:"
    log $BLUE "  kubectl get nodes"  
    log $BLUE "  kubectl get pods -A"
    
    echo ""
    log $BLUE "Monitor AutoIndexer logs:"
    log $BLUE "  kubectl logs -f -l app=autoindexer -n $NAMESPACE_AUTOINDEXER"
    log $BLUE "  kubectl get autoindexer -w"
    
    echo ""
    log $BLUE "Monitor RAGEngine:"
    log $BLUE "  kubectl get ragengine ragengine -w"
    log $BLUE "  kubectl describe ragengine ragengine"
    
    echo ""
    log $BLUE "Monitor Karpenter CRDs:"
    log $BLUE "  kubectl get crd | grep karpenter  # Check installed CRDs" 
    log $BLUE "  kubectl get nodepools -A          # View NodePool resources (will be empty)"
    log $BLUE "  kubectl get nodeclaims -A         # View NodeClaim resources (will be empty)"  
    log $BLUE "  kubectl explain nodepool          # View NodePool API schema"
    log $BLUE "  kubectl explain nodeclaim         # View NodeClaim API schema"
    
    echo ""
    log $BLUE "Access Qdrant (internal - port forward only):"
    log $BLUE "  kubectl port-forward svc/qdrant 6333:6333"
    
    echo ""
    log $BLUE "Access RAGEngine (external access available!):"
    log $BLUE "  External: http://localhost:5789"
    log $BLUE "  Internal: kubectl port-forward svc/ragengine 5000:80"
    log $BLUE "  Test: curl -X POST http://localhost:5789/retrieve \\"
    log $BLUE "            -H 'Content-Type: application/json' \\"
    log $BLUE "            -d '{\"index_name\": \"kaito-codebase\", \"query\": \"what is KAITO?\", \"max_node_count\": 5}'"
    log $GREEN "  🌐 Direct access: http://localhost:5789"
    log $BLUE "  📊 API endpoints:"
    log $BLUE "    • Health: curl http://localhost:5789/healthz"
    log $BLUE "    • Retrieve: curl -X POST http://localhost:5789/retrieve -H 'Content-Type: application/json' -d '{\"query\":\"test\"}'"
    log $BLUE "  🔄 Alternative (port forward): kubectl port-forward svc/ragengine 5789:80 -n $NAMESPACE_RAGENGINE"
    
    echo ""
    log $BLUE "Delete cluster when done:"
    log $BLUE "  kind delete cluster --name $KIND_CLUSTER_NAME"
    
    echo ""
    log $GREEN "🎉 KAITO RAGEngine + AutoIndexer with Karpenter CRDs is now running on kind!"
    log $GREEN "✅ Karpenter CRDs installed (CRDs only - no controller needed)"
    log $GREEN "🌐 RAGEngine accessible externally at http://localhost:5789"
    log $GREEN "🔒 Qdrant remains internal (access via port-forward only)"
}

# Main function
main() {
    log $GREEN "Starting KAITO RAGEngine + AutoIndexer deployment on kind..."
    
    # Check if we're in the right directory
    if [[ ! -f "$KIND_CONFIG" ]] || [[ ! -f "ragengine.yaml" ]]; then
        log $RED "Error: Required files not found. Please run this script from the qdrant-rag-autoindexer directory."
        exit 1
    fi
    
    check_prerequisites
    create_kind_cluster  
    install_karpenter
    install_kaito_crds
    deploy_stack
    show_cluster_info
}

# Trap to handle script interruption
trap 'log $RED "Script interrupted"; exit 1' INT

# Run main function
main "$@"