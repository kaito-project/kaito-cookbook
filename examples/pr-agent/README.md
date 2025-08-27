# KAITO Powered PR-Agent Setup Guide

This guide will help you set up your own KAITO-powered PR-agent using KAITO and GitHub.

---

## 1. Create a GitHub App

Follow the official instructions for creating a GitHub App:
[GitHub App Setup Guide](https://qodo-merge-docs.qodo.ai/installation/github/#run-as-a-github-app)

---

## 2. Configure Your `.secrets` File

For step #5, add the following settings to your `.secrets` file.
Example for the `qwen2.5-coder-32b-instruct` model:

```toml
[config]
model = "hosted_vllm/qwen2.5-coder-32b-instruct"         # Set by KAITO
fallback_models = ["hosted_vllm/qwen2.5-coder-32b-instruct"] # Set by you

[ollama]
api_base = "http://workspace-qwen-2-5-coder-32b-instruct:80/v1" # Base URL for your KAITO service

[github]
deployment_type = "app"         # Set to "app" (default is "user")
app_id = APP_ID                 # Your GitHub App ID
webhook_secret = WEBHOOK_SECRET # Your webhook secret
app_name = "kaito-pr-agent"     # Name of your app

[config]
ai_timeout = 600                # Increase timeout
custom_model_max_tokens = 32768 # Set to your model's maximum
```

---

## 3. Deploy Your Docker Image

After pushing your image to your Docker repository, deploy it to your AKS (Azure Kubernetes Service) cluster.

---

## 4. Set Up Azure Application Gateway Ingress Controller (AGIC)

To allow your GitHub App to communicate with your AKS container, set up AGIC.
**Note:** The container must be in the same cluster as your KAITO workspace.

- [Quickstart: Deploy Application Gateway for Containers (ALB Controller)](https://learn.microsoft.com/en-us/azure/application-gateway/for-containers/quickstart-deploy-application-gateway-for-containers-alb-controller)
- [Bring Your Own Deployment](https://learn.microsoft.com/en-us/azure/application-gateway/for-containers/quickstart-create-application-gateway-for-containers-byo-deployment)

---

## 5. Reference YAMLs

You can use the following repo for reference deployment YAMLs:
[ishaansehgal99/kaito-pr-review-demo](https://github.com/ishaansehgal99/kaito-pr-review-demo)

- Deployment: `config/github-app/pr-agent-github-app-deployment.yaml`
- Service: `config/github-app/pr-agent-github-app-service.yaml`

---

## 6. Finish GitHub App Settings

When prompted for the webhook URL in your GitHub App:

- Use your AGIC endpoint, e.g.:
  ```
  http://<your-agic-endpoint>.alb.azure.com/api/v1/github_webhooks
  ```
- Set your webhook secret in the GitHub App settings (ensure it matches the value in your `.secrets` file).

---

## Troubleshooting & Support

If you encounter issues, refer to the documentation links above or the reference repository for working YAMLs.

