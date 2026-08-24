# Deployment Steps — SRE Platform on Azure (personal environment)

Tracks the actual steps taken to deploy this project to my own Azure environment via GitHub Actions + ArgoCD. Check off each step as it's completed. Update this file after every completed step — don't batch updates.

Status legend: `[ ]` not started · `[~]` in progress · `[x]` done

---

## Part 1 — Repo & environment setup

- [x] 1. Create my own GitHub repo and point this local clone's `origin` at it (was `jaeveloper/sre-proj-upgrade`) — repo: `https://github.com/MekusB/sre-proj-upgrade.git`
- [x] 2. Replace `repoURL` in all 18 ArgoCD files under `kubernetes-platform/argocd/` (`root-app.yaml` + every `apps/*.yaml`) to point at my repo
- [x] 3. Pick globally-unique names in `terraform/environments/dev/config.yaml`:
  - [x] 3a. `acr.name` → `srepjcoreacr`
  - [x] 3b. `keyvault.name` → `sre-core-pj-kv`
  - [x] 3c. `github_repo` → `MekusB/sre-proj-upgrade` (done alongside 3a/3b — same file, required for GitHub Actions OIDC trust to work with the new repo)
- [x] 4. Parameterize Cosmos DB and Redis names — added `var.name` to `terraform/modules/cosmos` and `terraform/modules/redis`, wired through `terraform/environments/dev/main.tf`, set `cosmos.name = sre-pj-cosmos` and `redis.name = sre-pj-redis-cart` in `config.yaml`
- [x] 5. `az login`
- [x] 6. `cd terraform/environments/dev && terraform init`
- [x] 7. `terraform plan` (review)
- [~] 8. `terraform apply` (first pass — in progress; Redis firewall IP will be wrong at this point, that's expected, fixed in step 15)
- [ ] 9. Set GitHub repo secrets from `terraform output`:
  - [ ] 9a. `ACR_LOGIN_SERVER` ← `terraform output acr_login_server`
  - [ ] 9b. `ACR_NAME` ← `terraform output acr_name`
  - [ ] 9c. `AZURE_CLIENT_ID` ← `terraform output github_actions_client_id`
  - [ ] 9d. `AZURE_TENANT_ID` ← `terraform output github_actions_tenant_id`
  - [ ] 9e. `AZURE_SUBSCRIPTION_ID` ← `terraform output azure_subscription_id`
- [ ] 10. Update `azure.workload.identity/client-id` annotations with fresh `terraform output worker_client_ids` values in:
  - [ ] 10a. `kustomize/base/cartservice/serviceaccount.yaml`
  - [ ] 10b. `kustomize/base/checkoutservice/serviceaccount.yaml`
  - [ ] 10c. `kustomize/base/productcatalogservice/serviceaccount.yaml`
  - [ ] 10d. `kustomize/workers/payment-worker/serviceaccount.yaml`
  - [ ] 10e. `kustomize/workers/email-worker/serviceaccount.yaml`
  - [ ] 10f. `kustomize/workers/shipping-worker/serviceaccount.yaml`
- [ ] 11. Update `kustomize/base/cartservice/secretproviderclass.yaml` — paste new cartservice `clientID` and `terraform output -raw azure_tenant_id` as `tenantId`
- [ ] 12. Update `kubernetes-platform/argocd/apps/keda.yaml` — replace `clientId`/`tenantId` with `terraform output keda_operator_client_id` and my tenant ID
- [ ] 13. `az aks get-credentials --resource-group sre-core-rg --name sre-aks --overwrite-existing` (adjust names if changed in `config.yaml`)
- [ ] 14. Install ArgoCD via Helm (`helm install argocd argo/argo-cd -n argocd --version 7.7.0 --set server.service.type=LoadBalancer`)
- [ ] 15. Get real AKS outbound IP and update `redis.aks_outbound_ip` in `config.yaml`, then re-run `terraform apply`
- [ ] 16. Commit and push all changes to `main` — triggers all 10 build workflows, populating ACR with real images
- [ ] 17. Verify all 10 workflow runs succeed (Actions tab) — fix any failures before proceeding
- [ ] 18. `kubectl apply -f kubernetes-platform/argocd/root-app.yaml`
- [ ] 19. Verify all ArgoCD Applications are `Synced`/`Healthy` (`kubectl get applications -n argocd`)
- [ ] 20. Verify pods running in `core`, `workers`, `keda`, `observability`, `argocd` namespaces
- [ ] 21. Access frontend via LoadBalancer external IP and confirm the storefront loads end-to-end (browse → add to cart → checkout)

---

## Part 2 — Documentation accuracy fixes

- [x] 22. Added GitHub CodeQL (init → autobuild → analyze) to all 12 `.github/workflows/build-*.yml`, immediately before the "Build Docker image" step, language-matched per service
- [ ] 23. Correct pipeline documentation: images push to **Azure Container Registry**, not Docker Hub (migrated 2026-07-08) — update any description that still says Docker Hub
- [ ] 24. Reconcile manifest location: either (a) rename `kustomize/` → `k8s/manifest` and update `spec.source.path` in all 17 `apps/*.yaml` + `root-app.yaml`, or (b) correct documentation to reference the real path `kustomize/overlays/dev/<service>`
- [ ] 25. Document the actual CD flow accurately: CI itself bumps the image tag and commits to `main` (not a manual manifest edit) before ArgoCD detects the change

---

## Notes / decisions log

- 2026-08-21: Repo set to `https://github.com/MekusB/sre-proj-upgrade.git`. Replaced `repoURL` in all 18 files under `kubernetes-platform/argocd/`. Set `acr.name = srepjcoreacr`, `keyvault.name = sre-core-pj-kv`, and `github_repo = MekusB/sre-proj-upgrade` in `terraform/environments/dev/config.yaml`. Note: `origin` remote itself (step 1) was not changed by me — only file contents. Still need to `git remote set-url origin https://github.com/MekusB/sre-proj-upgrade.git` (or equivalent) before pushing.
- 2026-08-21: Parameterized Cosmos DB and Redis names — added `variable "name"` to `terraform/modules/cosmos/variables.tf` and `terraform/modules/redis/variables.tf`, changed the hardcoded `name = "sre-cosmos"` / `name = "sre-redis-cart"` in each module's `main.tf` to `name = var.name`, and passed `name = local.config.cosmos.name` / `name = local.config.redis.name` from `terraform/environments/dev/main.tf`. Set `cosmos.name = sre-pj-cosmos` and `redis.name = sre-pj-redis-cart` in `config.yaml` — swap these if they turn out to already be taken (both must be globally unique across Azure).
- 2026-08-21: Added GitHub CodeQL to all 12 build workflows (10 core services + loadgenerator + shoppingassistantservice), inserted right before "Build Docker image": `init` → `autobuild` → `analyze` for compiled languages (go, csharp, java-kotlin — checkoutservice/frontend/productcatalogservice/shippingservice, cartservice, adservice), `init (build-mode: none)` → `analyze` for interpreted languages (python, javascript-typescript — emailservice/loadgenerator/recommendationservice/shoppingassistantservice, currencyservice/paymentservice). Added `security-events: write` to each workflow's `permissions:` block (required for CodeQL to upload SARIF results) — `shoppingassistantservice` had no `permissions:` block at all, so one was added (`contents: read` + `security-events: write`). No code changes needed to trigger this — findings show up under the repo's **Security → Code scanning** tab on GitHub once these workflows run. Note: CodeQL is only useful once GitHub Advanced Security / code scanning is enabled for the repo (free for public repos; for private repos it needs GHAS enabled, which is a paid feature on non-Enterprise plans) — confirm repo visibility/plan before expecting results to appear.
- 2026-08-21: Renamed the `jd`-prefixed resource group and AKS cluster to `sre`-prefixed: `rg_name` `jd-core-rg` → `sre-core-rg`, `aks.cluster_name` `jd-aks` → `sre-aks` in `config.yaml`. Propagated the same rename everywhere else these names were referenced: `terraform/environments/dev/providers.tf` (commented-out backend example: `jd-tfstate-rg`→`sre-tfstate-rg`, `jdtfstatesre`→`sretfstate`), `STEPS.md` step 13, `README.md`, and `README02/Infra-README.md`. Verified no `jd-` references remain anywhere in the repo. AKS cluster name and resource group are not globally-unique-namespace resources (only unique within the subscription/RG), so no collision risk like ACR/Key Vault/Cosmos/Redis.
