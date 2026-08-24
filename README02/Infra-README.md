# Infra README

Scope: Azure infrastructure architecture and provisioning for this platform.

## Change Highlights
- 2026-06-04: Initial Infra README created from main project README.
- 2026-06-04: Added production-baseline infra backlog and standards checklist.
- 2026-07-08: Added `modules/acr` (Azure Container Registry, admin disabled). Extended `modules/workload-identity` with an AKS→ACR `AcrPull` role assignment (kubelet identity, equivalent to `az aks update --attach-acr`) and a `github-actions-ci` managed identity + OIDC federated credential (trusts `repo:jaeveloper/sre-proj-upgrade:ref:refs/heads/main`) granted `AcrPush` on the registry — no registry credentials stored anywhere. `kustomize/overlays/dev/*/kustomization.yaml` now points every image at `srecoreacr.azurecr.io/*` instead of Docker Hub. Added a commented-out `backend "azurerm" {}` placeholder in `providers.tf` — state is still local until it's activated (see Operational Infra Notes below).
- 2026-07-08: CI migrated — all 10 deployed services' `.github/workflows/build-*.yml` now push immutable git-SHA-tagged images to ACR via the OIDC identity above and commit the tag bump back into the matching kustomize overlay. See `README02/DevOps-README.md` for details.
- 2026-07-09: Commented out (not deleted) everything that isn't open source in the observability stack, per request: `azurerm_log_analytics_workspace` and `azurerm_application_insights` in `modules/observability`, the AKS diagnostic setting that depended on the workspace (`modules/aks`), the `appinsights-config` ConfigMaps, the `observability-config` ArgoCD app, and the `azuremonitor` exporter + traces/logs pipelines in **both** otel-collector configs — the live one is inline Helm values in `kubernetes-platform/argocd/apps/otel-collector.yaml`, not the standalone `kubernetes-platform/observability/otel-collector/values.yaml` file (that file isn't referenced by anything; edited it too for consistency but confirm before relying on it). Metrics (Prometheus) pipeline is untouched. Traces and logs are now collected by the OTEL Collector and dropped — no destination configured. Open-source replacement path if/when wanted: Tempo (traces) + Loki (logs), both OTLP-exportable from the existing collector without adding a new receiver.
- 2026-07-09: **Found, not yet resolved**: `kubernetes-platform/argocd-helm/` is a full duplicate of `kubernetes-platform/argocd/` (own `root-app.yaml` + `apps/*.yaml`), but its `root-app.yaml` actually points `path:` at `kubernetes-platform/argocd/apps` (the real one) — so `argocd-helm/apps/*` (which still reference the pre-Kustomize `helm/core-services/*` paths) are orphaned and not deployed by anything. Looks like a leftover pre-migration backup. Left untouched pending a decision on whether to delete it.

## Infra Overview
This platform runs on Azure Kubernetes Service (AKS) with supporting managed services:
- AKS for compute
- Azure Service Bus for eventing
- Azure Cosmos DB for product catalog
- Azure Cache for Redis for cart persistence
- ~~Application Insights + Log Analytics for telemetry storage~~ — commented out 2026-07-09 (not open source); telemetry storage is Prometheus only until an open-source trace/log backend is added

## Terraform Layout
Path: terraform/
- environments/dev: environment entry point and config
- modules/aks: AKS cluster, OIDC issuer, diagnostics
- modules/network: VNet and AKS subnet
- modules/cosmos: Cosmos DB account, SQL database, container
- modules/servicebus: namespace, topic, subscriptions
- modules/redis: Redis cache + firewall rules
- modules/observability: Log Analytics + App Insights — commented out 2026-07-09 (not open source)
- modules/acr: Azure Container Registry (admin disabled)
- modules/workload-identity: managed identities, federated credentials, RBAC — including AKS→ACR pull and the GitHub Actions CI identity

## Current Dev Configuration
From terraform/environments/dev/config.yaml:
- Region: westus2
- Resource Group: sre-core-rg
- AKS: sre-aks
- Node pools: autoscaling enabled
- Cosmos throughput: 4000 RU/s
- Service Bus SKU: Standard

## Provisioning Flow
1. cd terraform/environments/dev
2. terraform init
3. terraform plan
4. terraform apply

## Important Outputs
- worker_client_ids
- keda_operator_client_id
- cosmos_endpoint
- redis_hostname
- app_insights_connection_string
- acr_login_server / acr_name — set as `ACR_LOGIN_SERVER` / `ACR_NAME` GitHub repo secrets once CI is migrated
- github_actions_client_id / github_actions_tenant_id / azure_subscription_id — set as `AZURE_CLIENT_ID` / `AZURE_TENANT_ID` / `AZURE_SUBSCRIPTION_ID` GitHub repo secrets (identifiers, not sensitive on their own — trust is enforced by the federated credential's repo/ref scoping, not by secrecy)

## Operational Infra Notes
### AKS stop/start for cost management
- az aks stop --name sre-aks --resource-group sre-core-rg
- az aks start --name sre-aks --resource-group sre-core-rg

### Redis outbound IP dependency
If AKS egress IP changes, update redis.aks_outbound_ip in terraform/environments/dev/config.yaml and apply Terraform.

### ACR name collision
`acr.name` in config.yaml (`srecoreacr`) must be globally unique across all of Azure. If `terraform apply` fails with a name-already-taken error, pick a different value before re-running — ACR names are alphanumeric only, no hyphens, 5-50 chars.

### Activating the remote backend
State is local (`terraform.tfstate` in `environments/dev/`) until the backend block in `providers.tf` is uncommented. Steps are in a comment directly above that block: create a storage account + container, fill in the real names, uncomment, then `terraform init -migrate-state`. Do this before more than one person/pipeline runs `terraform apply` against this environment — local state has no locking, so concurrent applies can corrupt it.

## Production Baseline Backlog (Infra)
- Activate the remote Terraform backend (scaffolded but commented out in `providers.tf` — needs a storage account provisioned first, then `terraform init -migrate-state`).
- Add stage and prod environments under terraform/environments/.
- Add private networking strategy for all data services where feasible (including a Premium-SKU ACR with a private endpoint, once volume justifies the cost over Basic).
- Add policy as code guardrails for required tags, SKUs, and diagnostics.
- Add backup/DR settings and tested recovery procedures.

## Standards Checklist
- IaC modules are reusable and environment-scoped.
- Diagnostics are enabled for critical resources.
- Identity is workload-based, not secret-based.
- Capacity settings are explicit and autoscaling is bounded.
- Environment promotion path exists (dev -> stage -> prod).
