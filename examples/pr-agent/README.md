To setup your own Kaito Powered PR-agent using Kaito do the following


Follow the following instructions for creating a GitHub App (https://qodo-merge-docs.qodo.ai/installation/github/#run-as-a-github-app)

...

For step #5 in your .secrets file copy in the following additional settings:

So for, `qwen2.5-coder-32b-instruct` for example you would add the following fields under the corresponding sections:

```toml
[config]
# models
model="hosted_vllm/qwen2.5-coder-32b-instruct" # Set by kaito
fallback_models=["hosted_vllm/qwen2.5-coder-32b-instruct"] # Set by us


[ollama]
api_base = "http://workspace-qwen-2-5-coder-32b-instruct:80/v1" # Set by us - the base url for your kaito service

[github]
deployment_type = "app" # Set by us - set to user by default

app_id = APP_ID  # Set by kaito - The GitHub App ID, replace with your own.
webhook_secret = WEBHOOK_SECRET  # Set by us - Optional, may be commented out.
app_name = "kaito-pr-agent" # Set by us

[config]
ai_timeout=600 # Set by us - Increase timeout
custom_model_max_tokens=32768 # Set by us - for models not in the default list - set to your models maximum
```

Then after pushing your image to docker repository. Run it in your AKS cluster. From here lets setup Azure Application Gateway Ingress Controller (AGIC) so that our GitHub App can make requests to our AKS container. Note that our this container must be in the same cluster as our kaito workspace. 

Follow these steps:

1. https://learn.microsoft.com/en-us/azure/application-gateway/for-containers/quickstart-deploy-application-gateway-for-containers-alb-controller


2. Bring your own deployment: https://learn.microsoft.com/en-us/azure/application-gateway/for-containers/quickstart-create-application-gateway-for-containers-byo-deployment


For reference YAMLs you can use the following repo: https://github.com/ishaansehgal99/kaito-pr-review-demo
This repo includes the reference pr-agent deployment: `config/github-app/pr-agent-github-app-deployment.yaml` and service `config/github-app/pr-agent-github-app-service.yaml`

Now you can finish the step 
```
Webhook URL: The URL of your app's server or the URL of the smee.io channel.
```

Then in your Github App you can
Set this to your AGIC endpoint (e.g. http://xxxxxxxxxx.xxxx.alb.azure.com/api/v1/github_webhooks)
As well as set your webhook secret

