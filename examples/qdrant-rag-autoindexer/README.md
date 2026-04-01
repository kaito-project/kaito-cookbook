# KAITO Qdrant RAGEngine + AutoIndexer Example

This guide will walk through the setup of a [KAITO RAGEngine](https://kaito-project.github.io/kaito/docs/rag) backed by Qdrant vector database and autofilled with code and documentation by the [KAITO AutoIndexer](https://github.com/kaito-project/autoindexer).

## Quick Start with Kind (Local Development)

For local development and testing, you can use the provided kind deployment script:

### Prerequisites

- [Docker](https://docs.docker.com/get-docker/) installed and running
- [kind](https://kind.sigs.k8s.io/docs/user/quick-start/) installed
- [kubectl](https://kubernetes.io/docs/tasks/tools/) installed  
- [helm](https://helm.sh/docs/intro/install/) installed

### Deploy to Kind

```bash
git clone https://github.com/kaito-project/kaito-cookbook.git
cd kaito-cookbook/examples/qdrant-rag-autoindexer
./deploy-on-kind.sh
```

This script will:
- Create a kind cluster with proper configuration
- Install Karpenter for node provisioning
- Deploy KAITO RAGEngine and AutoIndexer via Helm charts
- Deploy Qdrant vector database
- Create RAGEngine and AutoIndexer custom resources
- Provide monitoring and access commands

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

Once the AutoIndexers have completed you can now query the AutoIndexer `/retrieve` API to leverage hybrid seach functionality and get relevant context. The deployment script opens a local port at `localhost:5789` to the ragengine


1. Query the `/retrieve` endpoint

```bash
curl -X POST http://localhost:5789/retrieve \
     -H "Content-Type: application/json" \
     -d '{"index_name": "kaito-codebase", "query": "what vector stores are supported in the RAGEngine?", "max_node_count": 5}'
```

```json
{
    "query": "what is KAITO?",
    "results": [
        {
            "doc_id": "cc86eb0843ef01a3801d54e4380e3adcdb258b5a1f54d2ebd564f9b65ea35c17",
            "node_id": "83949ab9-b1cc-434b-b421-87cbaf495646",
            "text": "func createAndValidateIndexPod(ragengineObj *kaitov1beta1.RAGEngine) (map[string]any, error) {\n\tcurlCommand := `curl -X POST ` + ragengineObj.ObjectMeta.Name + `:80/index \\\n-H \"Content-Type: application/json\" \\\n-d '{\n    \"index_name\": \"kaito\",\n    \"documents\": [\n        {\n            \"text\": \"Kaito is an operator that automates the AI/ML model inference or tuning workload in a Kubernetes cluster\",\n            \"metadata\": {\"author\": \"kaito\", \"category\": \"kaito\"}\n        }\n    ]\n}'`\n\topts := PodValidationOptions{\n\t\tPodName:            fmt.Sprintf(\"index-pod-%s\", utils.GenerateRandomString()),\n\t\tCurlCommand:        curlCommand,\n\t\tNamespace:          ragengineObj.ObjectMeta.Namespace,\n\t\tExpectedLogContent: \"Kaito is an operator that automates the AI/ML model inference or tuning workload in a Kubernetes cluster\",\n\t\tWaitForRunning:     false,\n\t\tParseJSONResponse:  true,\n\t\tJSONStartMarker:    \"[\",\n\t\tJSONEndMarker:      \"]\",\n\t}\n\treturn createAndValidateAPIPod(ragengineObj, opts)\n}",
            "score": 0.5,
            "dense_score": 0.71294934,
            "sparse_score": null,
            "source": "dense_only",
            "metadata": {
                "autoindexer": "default_kaito-code-autoindexer",
                "source_type": "git",
                "repository": "https://github.com/kaito-project/kaito.git",
                "branch": "main",
                "file_path": "test/rage2e/rag_test.go",
                "change_type": "full",
                "timestamp": "2026-04-01T21:40:52.780599Z",
                "commit": "a9c5bef552aa673acac5714ccf50c42c9043aba6",
                "language": "go",
                "split_type": "code"
            }
        },
        {
            "doc_id": "1159984207f844f635d5a093499339c69f3d6e72d416ec9daf08963da508f287",
            "node_id": "ec95d483-b8e5-42c1-b102-6a43ac1f895e",
            "text": "// Copyright (c) KAITO authors.\n// Licensed under the Apache License, Version 2.0 (the \"License\");\n// you may not use this file except in compliance with the License.\n// You may obtain a copy of the License at\n//\n//     http://www.apache.org/licenses/LICENSE-2.0\n//\n// Unless required by applicable law or agreed to in writing, software\n// distributed under the License is distributed on an \"AS IS\" BASIS,\n// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.\n// See the License for the specific language governing permissions and\n// limitations under the License.\n\npackage main\n\nimport (\n\t_ \"github.com/kaito-project/kaito/presets/workspace/models\"\n\t_ \"github.com/kaito-project/kaito/presets/workspace/models/deepseek\"\n\t_ \"github.com/kaito-project/kaito/presets/workspace/models/falcon\"\n\t_ \"github.com/kaito-project/kaito/presets/workspace/models/gemma3\"\n\t_ \"github.com/kaito-project/kaito/presets/workspace/models/gpt\"\n\t_ \"github.com/kaito-project/kaito/presets/workspace/models/llama3\"\n\t_ \"github.com/kaito-project/kaito/presets/workspace/models/mistral\"\n\t_ \"github.com/kaito-project/kaito/presets/workspace/models/phi3\"\n\t_ \"github.com/kaito-project/kaito/presets/workspace/models/phi4\"\n\t_ \"github.com/kaito-project/kaito/presets/workspace/models/qwen\"\n)",
            "score": 0.5,
            "dense_score": null,
            "sparse_score": 0.0019141121,
            "source": "sparse_only",
            "metadata": {
                "autoindexer": "default_kaito-code-autoindexer",
                "source_type": "git",
                "repository": "https://github.com/kaito-project/kaito.git",
                "branch": "main",
                "file_path": "cmd/workspace/models.go",
                "change_type": "full",
                "timestamp": "2026-04-01T21:41:52.168422Z",
                "commit": "a9c5bef552aa673acac5714ccf50c42c9043aba6",
                "language": "go",
                "split_type": "code"
            }
        },
        {
            "doc_id": "47a90ce4f1ca88b9856e6cedbb364e74885990201ccae90b58c97c6173b6a485",
            "node_id": "ca3273a5-65c2-4a85-886e-1827b136191b",
            "text": "queryServiceName:\n                description: |-\n                  QueryServiceName is the name of the service which exposes the endpoint for accepting user queries to the\n                  inference service. If not specified, a default service name will be created by the RAG engine.\n                type: string\n              storage:\n                description: |-\n                  Storage specifies how to access the vector database used to save the embedding vectors.\n                  If this field is not specified, by default, an in-memory vector DB will be used.\n                  The data will not be persisted.\n                properties:\n                  mountPath:\n                    description: |-\n                      MountPath specifies where the volume should be mounted in the container.\n                      Defaults to /mnt/data if not specified.\n                    type: string\n                  persistentVolumeClaim:\n                    description: |-\n                      PersistentVolumeClaim specifies the PVC to use for persisting vector database data.\n                      If not specified, an emptyDir will be used (data will be lost on pod restart).\n                    type: string\n                type: object",
            "score": 0.47564112646253526,
            "dense_score": 0.71181566,
            "sparse_score": null,
            "source": "dense_only",
            "metadata": {
                "autoindexer": "default_kaito-code-autoindexer",
                "source_type": "git",
                "repository": "https://github.com/kaito-project/kaito.git",
                "branch": "main",
                "file_path": "config/crd/bases/kaito.sh_ragengines.yaml",
                "change_type": "full",
                "timestamp": "2026-04-01T21:41:20.615823Z",
                "commit": "a9c5bef552aa673acac5714ccf50c42c9043aba6",
                "language": "yaml",
                "split_type": "code"
            }
        },
        {
            "doc_id": "96136bdaab03c8ce505e1b776fdeded58f362f1c481332fa712f6df3d54f5c54",
            "node_id": "1649d5e5-64e7-4371-9dc8-26d8b0952aa8",
            "text": "import (\n\t\"context\"\n\t\"flag\"\n\t\"fmt\"\n\t\"os\"\n\t\"os/signal\"\n\t\"strconv\"\n\t\"syscall\"\n\t\"time\"\n\n\t//+kubebuilder:scaffold:imports\n\tazurev1beta1 \"github.com/Azure/karpenter-provider-azure/pkg/apis/v1beta1\"\n\thelmv2 \"github.com/fluxcd/helm-controller/api/v2\"\n\tsourcev1 \"github.com/fluxcd/source-controller/api/v1\"\n\t\"k8s.io/apimachinery/pkg/runtime\"\n\tutilruntime \"k8s.io/apimachinery/pkg/util/runtime\"\n\t\"k8s.io/client-go/kubernetes\"\n\tclientgoscheme \"k8s.io/client-go/kubernetes/scheme\"\n\t_ \"k8s.io/client-go/plugin/pkg/client/auth\"\n\t\"k8s.io/client-go/rest\"\n\t\"k8s.io/klog/v2\"\n\t\"knative.dev/pkg/injection/sharedmain\"\n\t\"knative.dev/pkg/webhook\"\n\tctrl \"sigs.k8s.io/controller-runtime\"\n\truntimecache \"sigs.k8s.io/controller-runtime/pkg/cache\"\n\t\"sigs.k8s.io/controller-runtime/pkg/healthz\"\n\t\"sigs.k8s.io/controller-runtime/pkg/log\"\n\t\"sigs.k8s.io/controller-runtime/pkg/log/zap\"\n\tmetricsserver \"sigs.k8s.io/controller-runtime/pkg/metrics/server\"\n\n\tkaitov1alpha1 \"github.com/kaito-project/kaito/api/v1alpha1\"\n\tkaitov1beta1 \"github.com/kaito-project/kaito/api/v1beta1\"\n\t\"github.com/kaito-project/kaito/pkg/featuregates\"\n\t\"github.com/kaito-project/kaito/pkg/inferenceset\"\n\t\"github.com/kaito-project/kaito/pkg/k8sclient\"\n\tkaitoutils \"github.com/kaito-project/kaito/pkg/utils\"\n\t\"github.com/kaito-project/kaito/pkg/utils/consts\"\n\t\"github.com/kaito-project/kaito/pkg/version\"\n\t\"github.com/kaito-project/kaito/pkg/workspace/controllers\"\n\t\"github.com/kaito-project/kaito/pkg/workspace/webhooks\"\n)",
            "score": 0.3586347852383292,
            "dense_score": null,
            "sparse_score": 0.0018924217,
            "source": "sparse_only",
            "metadata": {
                "autoindexer": "default_kaito-code-autoindexer",
                "source_type": "git",
                "repository": "https://github.com/kaito-project/kaito.git",
                "branch": "main",
                "file_path": "cmd/workspace/main.go",
                "change_type": "full",
                "timestamp": "2026-04-01T21:41:52.169334Z",
                "commit": "a9c5bef552aa673acac5714ccf50c42c9043aba6",
                "language": "go",
                "split_type": "code"
            }
        },
        {
            "doc_id": "de3be3e7976bc9cab5abc837b8448a06be03128bab803a143ed9f06f6922bdb4",
            "node_id": "2715e97c-69d5-4c11-8c94-07ef24fa643c",
            "text": "// Copyright (c) KAITO authors.\n// Licensed under the Apache License, Version 2.0 (the \"License\");\n// you may not use this file except in compliance with the License.\n// You may obtain a copy of the License at\n//\n//     http://www.apache.org/licenses/LICENSE-2.0\n//\n// Unless required by applicable law or agreed to in writing, software\n// distributed under the License is distributed on an \"AS IS\" BASIS,\n// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.\n// See the License for the specific language governing permissions and\n// limitations under the License.\n\npackage e2e\n\nimport (\n\t\"fmt\"\n\t\"io\"\n\t\"math/rand\"\n\t\"strconv\"\n\t\"strings\"\n\t\"time\"\n\n\thelmv2 \"github.com/fluxcd/helm-controller/api/v2\"\n\tsourcev1 \"github.com/fluxcd/source-controller/api/v1\"\n\t. \"github.com/onsi/ginkgo/v2\"\n\t. \"github.com/onsi/gomega\"\n\t\"github.com/samber/lo\"\n\tcorev1 \"k8s.io/api/core/v1\"\n\tmetav1 \"k8s.io/apimachinery/pkg/apis/meta/v1\"\n\t\"k8s.io/client-go/kubernetes\"\n\t\"sigs.k8s.io/controller-runtime/pkg/client\"\n\n\tkaitov1alpha1 \"github.com/kaito-project/kaito/api/v1alpha1\"\n\tkaitov1beta1 \"github.com/kaito-project/kaito/api/v1beta1\"\n\tkaitoutils \"github.com/kaito-project/kaito/pkg/utils\"\n\t\"github.com/kaito-project/kaito/pkg/utils/consts\"\n\tcontrollers \"github.com/kaito-project/kaito/pkg/workspace/controllers\"\n\t\"github.com/kaito-project/kaito/test/e2e/utils\"\n)",
            "score": 0.1842686684672095,
            "dense_score": null,
            "sparse_score": 0.0018656678,
            "source": "sparse_only",
            "metadata": {
                "autoindexer": "default_kaito-code-autoindexer",
                "source_type": "git",
                "repository": "https://github.com/kaito-project/kaito.git",
                "branch": "main",
                "file_path": "test/e2e/preset_vllm_test.go",
                "change_type": "full",
                "timestamp": "2026-04-01T21:40:52.787569Z",
                "commit": "a9c5bef552aa673acac5714ccf50c42c9043aba6",
                "language": "go",
                "split_type": "code"
            }
        }
    ],
    "count": 5
}
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