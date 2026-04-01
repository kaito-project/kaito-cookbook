# Qdrant RAG Helm Chart

This Helm chart deploys a complete KAITO Qdrant RAGEngine with AutoIndexer setup, specifically configured for CPU deployments.

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- KAITO Workspace controller installed
- KAITO RAGEngine controller installed
- KAITO AutoIndexer controller installed
- Appropriate node pools with correct labels (see Node Pool Requirements)

## Installation

### Quick Installation

```bash
# Recommended: Install with Helm wait flags for proper dependency management
helm install qdrant-rag ./chart --wait --wait-for-jobs --timeout 10m

# Install with custom values (still use wait flags)
helm install qdrant-rag ./chart --values ./chart/values.yaml --wait --wait-for-jobs --timeout 10m

# Install for local/minimal testing
helm install qdrant-rag ./chart --values ./chart/values-local-minimal.yaml --wait --wait-for-jobs --timeout 10m
```

> **💡 Important**: Always use `--wait --wait-for-jobs --timeout 10m` flags for proper startup order. This ensures RAGEngine is ready before AutoIndexers start, preventing connection errors.

### Custom Installation

```bash
# Install with custom namespace and release name
helm install my-rag-setup ./chart \
  --namespace my-namespace \
  --create-namespace \
  --set namespace=my-namespace \
  --wait --wait-for-jobs --timeout 10m

# Install with specific instance type
helm install qdrant-rag ./chart \
  --set ragengine.compute.instanceType="Standard_D16s_v3" \
  --wait --wait-for-jobs --timeout 10m
```

## Node Pool Requirements

This chart is designed for CPU deployments and expects node pools with specific labels:

### Qdrant Node Pool
```bash
az aks nodepool add \
  --resource-group <RESOURCE_GROUP_NAME> \
  --cluster-name <CLUSTER_NAME> \
  --name qdrantpool \
  -s Standard_D16s_v5 \
  -c 1 \
  --labels workload=qdrant
```

### RAGEngine Node Pool
```bash
az aks nodepool add \
  --resource-group <RESOURCE_GROUP_NAME> \
  --cluster-name <CLUSTER_NAME> \
  --name ragcpupool \
  -s Standard_D8_v3 \
  -c 1 \
  --labels workload=ragengine
```

## Configuration

### Key Configuration Options

| Parameter | Description | Default |
|-----------|-------------|---------|
| `qdrant.enabled` | Enable Qdrant deployment | `true` |
| `qdrant.resources.requests.cpu` | CPU request for Qdrant | `"8"` |
| `qdrant.resources.requests.memory` | Memory request for Qdrant | `"32Gi"` |
| `qdrant.persistence.size` | Storage size for Qdrant | `"30Gi"` |
| `ragengine.enabled` | Enable RAGEngine deployment | `true` |
| `ragengine.compute.instanceType` | Instance type for RAGEngine | `"Standard_D8_v3"` |
| `ragengine.compute.count` | Number of RAGEngine instances | `1` |
| `autoindexer.enabled` | Enable AutoIndexer deployments | `true` |
| `autoindexer.codeIndexer.enabled` | Enable code indexing | `true` |
| `autoindexer.docsIndexer.enabled` | Enable documentation indexing | `true` |

### Values Files

- `values.yaml`: Default production configuration for CPU deployments
- `values-local-minimal.yaml`: Minimal configuration for local testing

## Dependency Management

This chart ensures proper startup order using Helm's native mechanisms to prevent AutoIndexer connection errors:

### How It Works

1. **Helm --wait**: Waits for RAGEngine deployment to be ready before marking install as successful
2. **Post-Install Hooks**: AutoIndexers use post-install hooks (weights 10-11) to start only after main install completes
3. **--wait-for-jobs**: Waits for AutoIndexer jobs to complete during installation
4. **Configurable Timeout**: Use `--timeout` flag to adjust wait duration

### Installation Command

**Always use these flags for proper dependency management:**

```bash
helm install qdrant-rag ./chart --wait --wait-for-jobs --timeout 10m
```

### Benefits

- ✅ **Eliminates "Connection Refused" errors** during initial deployment
- ✅ **Uses standard Helm patterns** instead of custom hooks
- ✅ **Simpler and more reliable** than custom readiness checks
- ✅ **Better error handling** with native Helm retry logic
- ✅ **No custom scripts** to maintain or debug

### Hook Weights

The chart uses these hook weights for proper sequencing:
- **Code AutoIndexer**: `post-install` weight `10`
- **Docs AutoIndexer**: `post-install` weight `11`

This ensures AutoIndexers only start after RAGEngine is fully ready.

## Usage

### Accessing the RAGEngine

1. Port-forward the RAGEngine service:
   ```bash
   kubectl port-forward svc/ragengine 5789:80
   ```

2. Test the retrieve API:
   ```bash
   curl -X POST http://localhost:5789/retrieve \
        -H "Content-Type: application/json" \
        -d '{"index_name": "kaito-codebase", "query": "what vector stores are supported?", "max_node_count": 5}'
   ```

### Accessing Qdrant

1. Port-forward the Qdrant service:
   ```bash
   kubectl port-forward svc/<release-name>-qdrant-rag-qdrant 6333:6333
   ```

2. Access the Qdrant web UI at: http://localhost:6333

### Monitoring

Check the status of all components:

```bash
# Check pods
kubectl get pods -l app.kubernetes.io/name=qdrant-rag

# Check RAGEngine status
kubectl get ragengine

# Check AutoIndexer status
kubectl get autoindexer

# Monitor AutoIndexer logs
kubectl logs -l component=code-autoindexer
kubectl logs -l component=docs-autoindexer
```

## Customization

### Using Different Repositories

To index your own repositories, modify the AutoIndexer configuration:

```yaml
autoindexer:
  codeIndexer:
    dataSource:
      git:
        repository: https://github.com/your-org/your-repo.git
        branch: main
        paths:
          - '*.py'
          - '*.js'
          - '*.ts'
```

### Disabling Components

To disable specific components:

```yaml
# Disable AutoIndexer completely
autoindexer:
  enabled: false

# Disable only documentation indexing
autoindexer:
  docsIndexer:
    enabled: false
```

### Resource Limits

Adjust resources based on your needs:

```yaml
qdrant:
  resources:
    requests:
      cpu: "4"
      memory: "16Gi"
    limits:
      cpu: "8"
      memory: "32Gi"
```

## Troubleshooting

### Common Issues

1. **Pods stuck in Pending**: Check node pool labels and resource availability
2. **RAGEngine not ready**: Ensure KAITO controllers are installed and running
3. **AutoIndexer failing**: Check network connectivity to Git repositories
4. **Qdrant storage issues**: Verify persistent volume claims and storage classes

### Debugging Commands

```bash
# Check events
kubectl get events --sort-by=.metadata.creationTimestamp

# Describe problematic resources
kubectl describe ragengine ragengine
kubectl describe autoindexer kaito-code-autoindexer

# Check controller logs
kubectl logs -n kaito-workspace -l app=kaito-workspace
kubectl logs -n kaito-ragengine -l app=ragengine-controller
kubectl logs -n kaito-autoindexer -l app=autoindexer-controller
```

## Uninstallation

```bash
helm uninstall qdrant-rag
```

Note: This will not automatically delete persistent volumes. To delete them:

```bash
kubectl delete pvc -l app.kubernetes.io/name=qdrant-rag
```

## Contributing

This chart is part of the KAITO cookbook. For issues and contributions, please visit:
- [KAITO Project](https://github.com/kaito-project/kaito)
- [KAITO Cookbook](https://github.com/kaito-project/kaito-cookbook)