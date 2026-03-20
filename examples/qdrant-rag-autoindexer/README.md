# KAITO Qdrant RAGEngine + AutoIndexer Example

This guide will walk through the setup of a [KAITO RAGEngine](https://kaito-project.github.io/kaito/docs/rag) backed by Qdrant vector database and autofilled with code and documentation by the [KAITO AutoIndexer](https://github.com/kaito-project/autoindexer).

## Cluster Creation

1. Create a resource group for your AKS cluster:

```bash
az group create --name <RESOURCE_GROUP_NAME> --location <LOCATION>
```

2. Create an AKS cluster with node auto provisioning enabled:

```bash
az aks create \
    --resource-group <RESOURCE_GROUP_NAME> \
    --name <CLUSTER_NAME> \
    --enable-addons monitoring \
    --generate-ssh-keys \
    --node-provisioning-mode Auto
```

3. Get credentials for your AKS cluster:

```bash
az aks get-credentials --resource-group <RESOURCE_GROUP_NAME> --name <CLUSTER_NAME>
```

## Nodepool Creation

### Qdrant Pool Creation

1. Create a dedicated nodepool for Qdrant using the Azure CLI:

```bash
az aks nodepool add \
    --resource-group <RESOURCE_GROUP_NAME> \
    --cluster-name <CLUSTER_NAME> \
    --name qdrantpool \
    -s Standard_D16s_v5 \
    -c 1 \
    --labels workload=qdrant
```

### RAG Pool Creation

You can choose between CPU-based or GPU-based nodes for your RAG workloads:

#### Option A: CPU-Based RAG Nodes

For cost-effective RAG workloads using CPU nodes:

```bash
az aks nodepool add \
    --resource-group <RESOURCE_GROUP_NAME> \
    --cluster-name <CLUSTER_NAME> \
    --name ragcpupool \
    -s Standard_D8_v3 \
    -c 1 \
    --labels workload=ragengine
```

#### Option B: GPU-Based RAG Nodes

For high-performance RAG workloads requiring GPU acceleration:

```bash
az aks nodepool add \
    --resource-group <RESOURCE_GROUP_NAME> \
    --cluster-name <CLUSTER_NAME> \
    --name raggpupool \
    -s Standard_NV36ads_A10_v5 \
    -c 1 \
    --labels workload=ragengine
```

*Note: GPU nodes require access to [Standard_NV36ads_A10_v5](https://learn.microsoft.com/en-us/azure/virtual-machines/sizes/gpu-accelerated/nvadsa10v5-series?tabs=sizebasic) instances or equivalent GPU-enabled node types.*

## Clone the cookbook repository

```bash
git clone https://github.com/kaito-project/kaito-cookbook.git
cd kaito-cookbook/examples/qdrant-rag-autoindexer
```

## Qdrant Setup

1. Create [`Qdrant PVC`](./qdrant-pvc.yaml) for persistent storage of the vector db.

```bash
kubectl apply -f qdrant-pvc.yaml
```

2. Deploy [`Qdrant`](./qdrant.yaml) deployment.

```bash
kubectl apply -f qdrant.yaml
```

3. Deploy [`Qdrant Service`](./qdrant-service.yaml) so the ragengine can communicate with qdrant.

```bash
kubectl apply -f qdrant-service.yaml
```

## KAITO Setup
1. Install KAITO Workload

```bash
helm repo add kaito https://kaito-project.github.io/kaito/charts/kaito
helm repo update
helm upgrade --install kaito-workspace kaito/workspace \
  --namespace kaito-workspace \
  --create-namespace \
  --wait \
  --take-ownership
```

## RAGEngine Setup

1. Install KAITO RAGEngine

```bash
helm upgrade --install kaito-ragengine oci://ghcr.io/kaito-project/charts/ragengine \
--version 0.9.3-qdrant.2 \
--namespace kaito-ragengine \
--create-namespace \
--take-ownership
```

2. Configure and deploy the [`ragengine.yaml`](./ragengine.yaml) custom resource.

   The provided configuration uses the **BYO (Bring Your Own) nodes** approach with `labelSelector` to target your pre-created nodepools.
   
   **To use GPU nodes**: The default configuration targets GPU nodes with `workload: ragengine` label. You may change the `instanceType` to reflect the GPU sku you have available to you.
   
   **To use CPU nodes**: Edit [`ragengine.yaml`](./ragengine.yaml) and:
   - Edit the `instanceType` field to match the CPU nodepool created earlier (`Standard_D8_v3`)
   
   **Alternative - Auto-provisioning**: If you prefer auto-provisioning instead of BYO nodes:
   - Comment out the `labelSelector` section

```bash
kubectl apply -f ragengine.yaml
```

## AutoIndexer Setup

1. Install KAITO AutoIndexer

```bash
helm upgrade --install kaito-autoindexer oci://ghcr.io/kaito-project/charts/autoindexer \
--version 0.0.0-dev.2 \
--namespace kaito-autoindexer \
--create-namespace \
--take-ownership
```

2. Deploy [`kaito-code-autoindexer`](./kaito-code-autoindexer.yaml) and [`kaito-docs-autoindexer`](./kaito-docs-autoindexer.yaml) custom resources.

```bash
kubectl apply -f kaito-code-autoindexer.yaml
kubectl apply -f kaito-docs-autoindexer.yaml
```

Once deployed, you can validate the custom resources are deployed with `kubectl get ragai`.

You can then validate the AutoIndexer logs are checking out the repository and indexing documents to the RAGEngine.


```
k logs kaito-code-autoindexer-job-2dxdg | grep body
...
    "body": "Initialized git data source handler for repository: https://github.com/kaito-project/kaito.git",
    "body": "AutoIndexer initialized for index 'kaito-codebase' with data source type 'Git'",
    "body": "Starting document indexing process",
    "body": "Added condition 'AutoIndexerIndexing' to AutoIndexer default/kaito-code-autoindexer",
    "body": "Created working directory: /tmp/autoindexer_git_l1b_u0m4",
    "body": "Cloning repository from https://github.com/kaito-project/kaito.git",
    "body": "Current commit hash: 6d94fc5551a71477372d601f689f176025744f50",
    "body": "Full repository indexing",
    "body": "Found 361 files in repository for indexing",
    "body": "Indexing batch of 10 documents (10/361 files processed)",
    "body": "Indexing batch of 10 documents into index 'kaito-codebase'",
    "body": "HTTP Request: POST http://ragengine.default.svc.cluster.local/index \"HTTP/1.1 200 OK\"",
...
    "body": "Updated AutoIndexer default/kaito-code-autoindexer status",
    "body": "HTTP Request: GET http://ragengine.default.svc.cluster.local/indexes/kaito-codebase/documents?limit=1&offset=0&max_text_length=1000&metadata_filter=%7B%22autoindexer%22%3A+%22default_kaito-code-autoindexer%22%7D \"HTTP/1.1 200 OK\"",
    "body": "Indexing completed successfully",
    "body": "Added condition 'AutoIndexerIndexing' to AutoIndexer default/kaito-code-autoindexer",
    "body": "Updating AutoIndexer default/kaito-code-autoindexer status with: {'lastIndexingTimestamp': '2026-03-20T17:08:05.915089Z', 'lastIndexingDurationSeconds': 800, 'numOfDocumentInIndex': 3787, 'successfulIndexingCount': 1}",
    "body": "Updated AutoIndexer default/kaito-code-autoindexer status",
    "body": "Created Kubernetes event 'IndexingCompleted' for AutoIndexer default/kaito-code-autoindexer",
    "body": "AutoIndexer job completed successfully",
```

## Query The RAGEngine for Relevant Context

Once the AutoIndexers have completed you can now query the AutoIndexer `/retrieve` API to leverage hybrid seach functionality and get relevant context.

1. Port Forward the RAGEngine Service

```bash
kubectl port-forward svc/ragengine 5789:80
```

2. Query the `/retrieve` endpoint

```bash
curl -X POST http://localhost:5789/retrieve \
     -H "Content-Type: application/json" \
     -d '{"index_name": "kaito-codebase", "query": "what vector stores are supported in the RAGEngine?", "max_node_count": 5}'
```

```bash
{"query":"what vector stores are supported in the RAGEngine?","results":[{"doc_id":"420f1844f03344a453a464ad3954c17ea2bf7470cdbb7ce14762955afd0a769c","node_id":"66b83b7c-bad0-4938-bb4a-fc0e4a0c649d","text":"type RAGEngineSpec struct {\n\t// Compute specifies the dedicated GPU resource used by an embedding model running locally if required.\n\t// +optional\n\tCompute *ResourceSpec `json:\"compute,omitempty\"`\n\t// Storage specifies how to access the vector database used to save the embedding vectors.\n\t// If this field is not specified, by default, an in-memory vector DB will be used.\n\t// The data will not be persisted.\n\t// +optional\n\tStorage *StorageSpec `json:\"storage,omitempty\"`\n\t// Embedding specifies whether the RAG engine generates embedding vectors using a remote service\n\t// or using a embedding model running locally.\n\tEmbedding        *EmbeddingSpec        `json:\"embedding\"`\n\tInferenceService *InferenceServiceSpec `json:\"inferenceService\"`\n}\n\n// RAGEngineStatus defines the observed state of RAGEngine\ntype RAGEngineStatus struct {\n\t// WorkerNodes is the list of nodes chosen to run the workload based on the RAGEngine resource requirement.\n\t// +optional\n\tWorkerNodes []string `json:\"workerNodes,omitempty\"`\n\n\tConditions []metav1.Condition `json:\"conditions,omitempty\"`\n}\n\n// RAGEngine is the Schema for the ragengine API\n// +kubebuilder:object:root=true\n// +kubebuilder:subresource:status\n// +kubebuilder:resource:path=ragengines,scope=Namespaced,categories=ragengine,shortName=rag\n// +kubebuilder:storageversion\n// +kubebuilder:printcolumn:name=\"Instance\",type=\"string\",JSONPath=\".spec.compute.instanceType\",description=\"\"","score":0.5,"dense_score":0.7500975,"sparse_score":null,"source":"dense_only","metadata":{"autoindexer":"default_kaito-code-autoindexer","source_type":"git","repository":"https://github.com/kaito-project/kaito.git","branch":"main","file_path":"api/v1beta1/ragengine_types.go","change_type":"full","timestamp":"2026-03-20T17:06:09.571000Z","commit":"6d94fc5551a71477372d601f689f176025744f50","language":"go","split_type":"code"}},...],"count":5}
```

3. Or Leverage the [`kaito-rag-engine-client`](https://pypi.org/project/kaito-rag-engine-client/) python library in your application to programatically create retrieve calls.

```python
from kaito_rag_engine_client import Client
from kaito_rag_engine_client.models import RetrieveRequest
from kaito_rag_engine_client.api.index import retrieve_index

client = Client(base_url="http://localhost:5789")

retrieve_resp = retrieve_index.sync(client=client, body=RetrieveRequest.from_dict({
        "index_name": "test_index",
        "query": "what can you tell me about AI?",
        "max_node_count": 5,
    }
))
```