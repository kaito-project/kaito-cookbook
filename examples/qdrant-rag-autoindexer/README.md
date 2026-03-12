# KAITO Qdrant RAGEengine + AutoIndexer Example

This guide will walk through the setup of a KAITO RAGEngine backed by Qdrant vector databse and autofilled with code and documentation by the KAITO AutoIndexer.

## Prerequisites

- An AKS cluster which you have gone through the [KAITO Azure Setup](https://kaito-project.github.io/kaito/docs/azure) for.
- Access to [Standard_NV36ads_A10_v5](https://learn.microsoft.com/en-us/azure/virtual-machines/sizes/gpu-accelerated/nvadsa10v5-series?tabs=sizebasic) nodes (or equivalent instance types).

## Clone the cookbook reposiutory

```bash
git clone https://github.com/kaito-project/kaito-cookbook.git
cd kaito-cookbook/examples/rag-autoindexer
```

## Qdrant Setup

1. Provision nodes for qdrant using the az cli. Leverage the command below and swap out `RESOURCE_GROUP_NAME` and `CLUSTER_NAME` for your aks cluster.

```bash
az aks nodepool add \
    --resource-group <RESOURCE_GROUP_NAME> \
    --cluster-name <CLUSTER_NAME> \
    --name qdrantpool \
    -s Standard_D16s_v5 \
    -c 1 \
    --labels app=qdrant
```

2. Create [`Qdrant PVC`](./qdrant-pvc.yaml) for persistent storage of the vector db.

```bash
kubectl apply -f qdrant-pvc.yaml
```

2. Deploy [`Qdrant`](./qdrant.yaml) deployment.

```bash
kubectl apply -f qdrant.yaml
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
helm repo add kaito https://kaito-project.github.io/kaito/charts/kaito
helm repo update
helm upgrade --install kaito-ragengine kaito/ragengine \
  --namespace kaito-ragengine \
  --create-namespace \
  --take-ownership
```

2. Deploy the [`Ragengine`](./ragengine.yaml) custom resource. If you are leveraging a different GPU sku, make sure you update the `instanceType` field within the resource definition to match your desired sku.

```bash
kubectl apply -f ragengine.yaml
```

## AutoIndexer Setup

1. Install KAITO AutoIndexer

```bash
helm repo add kaito https://kaito-project.github.io/kaito/charts/kaito
helm repo update
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
"body": "Loaded in-cluster Kubernetes configuration",
"body": "AutoIndexer K8s client initialized for namespace: default, autoindexer: kaito-code-autoindexer",
"body": "Kubernetes client initialized successfully",
"body": "Found AutoIndexer CRD configuration, using it to supplement environment config",
"body": "Applying configuration from AutoIndexer CRD",
"body": "Using index name from CRD: aks-wikis-claw",
"body": "Using RAG engine endpoint from CRD: http://ragengine.default.svc.cluster.local:80",
"body": "Using data source type from CRD: Git",
"body": "Updated Git data source configuration from CRD",
"body": "Initialized 2 content handlers",
"body": "Initialized git data source handler for repository: https://github.com/kaito-project/kaito.git",
"body": "AutoIndexer initialized for index 'kaito-codebase' with data source type 'Git'",
"body": "Starting document indexing process",
"body": "Added condition 'AutoIndexerIndexing' to AutoIndexer default/kaito-code-autoindexer",
"body": "Created working directory: /tmp/autoindexer_git_h1k94bs3",
"body": "Cloning repository from https://github.com/kaito-project/kaito.git",
"body": "Checked out branch: main",
...
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