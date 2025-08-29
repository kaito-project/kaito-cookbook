# Using KAITO Models with VS Code Copilot

This guide shows how to configure VS Code Copilot to use custom KAITO models.

## Prerequisites
- [VS Code Copilot Chat extension](https://marketplace.visualstudio.com/items?itemName=GitHub.copilot-chat)
- Access to a KAITO model endpoint

## Retrieving Model Information

Before configuring VS Code Copilot, you need to retrieve your model information:

```bash
# Retrieve model ID and context size
kubectl run -it --rm --restart=Never curl --image=curlimages/curl -- \
  curl -s http://$WORKSPACE_SVC/v1/models | jq
```

Example output:
```json
{
  "object": "list",
  "data": [
    {
      "id": "phi-4-mini-instruct",
      "object": "model",
      "created": 1755498783,
      "owned_by": "vllm",
      "root": "/workspace/vllm/weights",
      "parent": null,
      "max_model_len": 131072
    }
  ]
}
```

Use the `id` value for the model name in your configuration, and `max_model_len` for `maxInputTokens` and `maxOutputTokens`.

## Configuration

Add the following configuration to your VS Code `settings.json` file:

```json
"github.copilot.chat.customOAIModels": {
    "phi-4-mini-instruct": {
        "name": "my-custom-model",
        "url": "YOUR_MODEL_ENDPOINT_URL",
        "toolCalling": true,
        "vision": false,
        "thinking": true,
        "maxInputTokens": 65536,
        "maxOutputTokens": 65536,
        "requiresAPIKey": true
    }
}
```

### Configuration Options
- `name`: Friendly name for your model
- `url`: Endpoint URL for your Kaito model
- `toolCalling`: Set to `true` for tool/function calling support
- `vision`: Set to `true` if your model supports image inputs
- `thinking`: Enables thinking visualization
- `maxInputTokens`: Maximum context size (tokens)
- `maxOutputTokens`: Maximum generation length (tokens)
- `requiresAPIKey`: Set to `true` if your endpoint requires authentication

## Usage
1. After adding the configuration, restart VS Code
2. In the Copilot Chat panel, select your custom model from the model dropdown
3. Start chatting with your KAITO model!
