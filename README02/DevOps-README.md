# DevOps README

Scope: CI/CD, GitOps, packaging, deployment workflow, and release controls.

## Change Highlights
- 2026-06-04: Initial DevOps README created from main project README.
- 2026-06-04: Added release hardening guidance (immutable tags, promotion, policy gates).
- 2026-06-04: Added Kustomize frontend conversion scaffold at Kustomize/frontend (base + overlays/dev) to begin Helm-to-Kustomize migration service-by-service.
- 2026-06-04: Added Helm-to-Kustomize migration matrix and required config catalog for all applications in Kustomize/MIGRATION-CONFIG.md.
- 2026-07-08: Terraform now provisions an Azure Container Registry (`modules/acr`) and a GitHub Actions OIDC identity (`modules/workload-identity`) scoped to `AcrPush` on it. `kustomize/overlays/dev/*` image refs were switched from `jukpozi/*` (Docker Hub) to `srecoreacr.azurecr.io/*` (ACR).
- 2026-07-08: Migrated all 10 `.github/workflows/build-*.yml` (every service except `shoppingassistantservice`, which isn't deployed to the cluster) off Docker Hub. Each now: logs in via `azure/login` (OIDC, no stored credential), builds and tags the image with both `${{ github.sha }}` and `latest`, runs the same Trivy CRITICAL-severity gate as before against the SHA tag, pushes both tags to ACR via `az acr login` + `docker push`, then `sed`-bumps the `newTag:` in the matching `kustomize/overlays/dev/<service>/kustomization.yaml` (and the paired worker overlay for paymentservice/emailservice/shippingservice, since those 3 share an image with their worker) and commits+pushes that change back to `main`. No shared/reusable workflow was used — each file was edited in place, same structure as before, just with the auth/build/push/bump steps swapped. ArgoCD picks up the tag-bump commit on its next sync, so the tag that actually lands in the cluster is always the exact commit that was scanned and pushed.
- 2026-07-08: Required GitHub repo secrets (values from `terraform output` in `terraform/environments/dev`): `AZURE_CLIENT_ID` (`github_actions_client_id`), `AZURE_TENANT_ID` (`github_actions_tenant_id`), `AZURE_SUBSCRIPTION_ID` (`azure_subscription_id`), `ACR_LOGIN_SERVER` (`acr_login_server`), `ACR_NAME` (`acr_name`). Each workflow also needs `contents: write` on the default `GITHUB_TOKEN` (already set via `permissions:` in the workflow) to push the tag-bump commit — if branch protection on `main` requires PR review, the direct push step will fail and needs to become a PR instead.
- 2026-07-07: Completed Helm-to-Kustomize migration for all 10 core services and 3 KEDA workers. Removed the vendored GCP-only components/tests from `kustomize/` (AlloyDB, Spanner, Memorystore, Istio, Cymbal branding, etc. — none applicable to this Azure platform). All 13 ArgoCD Applications now point `spec.source.path` at `kustomize/overlays/dev/<service>` instead of `helm/...`; `helm/` is left in place untouched but is no longer referenced by anything. Every overlay validated with `kubectl kustomize` (client-side, no cluster required). Fixed a tracing bug carried over from the Helm charts: `paymentservice`, `currencyservice`, `recommendationservice`, `emailservice`, and their corresponding workers set `OTEL_EXPORTER_OTLP_ENDPOINT`, but those services' source only reads `COLLECTOR_SERVICE_ADDR` — tracing was silently a no-op for 5 of 10 services. Also flagged (not fixed): `cartservice-sa` has a workload-identity annotation and Service Bus RBAC grant in Terraform despite cartservice never calling Service Bus. Details in `kustomize/README.md`.

## Delivery Architecture
Source of truth is GitHub.
- Services are built by GitHub Actions.
- Images are pushed to Docker Hub.
- ArgoCD syncs manifests/charts from repository to AKS.

## GitOps (ArgoCD)
Bootstrap entry:
- kubernetes-platform/argocd/root-app.yaml

App-of-apps syncs everything under:
- kubernetes-platform/argocd/apps/

Common sync policy:
- automated prune
- automated selfHeal

## Current CI Pattern
Per-service workflows under .github/workflows/build-<service>.yml:
1. Checkout
2. Language build/test
3. Docker login
4. Build image
5. Trivy scan
6. Push image

## Deployment Steps (Current)
1. Provision infra using Terraform.
2. Connect kubectl to AKS.
3. Install ArgoCD.
4. Paste `terraform output -raw azure_tenant_id` into `kustomize/base/cartservice/secretproviderclass.yaml` (one-time per environment; not sensitive, just not knowable before apply).
5. Apply root ArgoCD app.
6. Validate all apps are Healthy/Synced — cartservice's `redis-secret` is created automatically by the Key Vault CSI driver, no manual `kubectl create secret` step anymore (2026-07-08).

## Why KEDA Is Used Here
KEDA enables event-driven autoscaling for worker services consuming Service Bus topics/subscriptions.
Benefits in this project:
- Scales worker deployments from zero when queue is empty.
- Scales up quickly on backlog.
- Reduces cost versus fixed worker replicas.
- Separates HTTP service scaling concerns from async queue consumers.

## Kustomize Instead Of Helm: Impact
Migration is complete (2026-07-07) — all 10 core services and 3 workers now deploy from `kustomize/`, not `helm/`. Trade-offs observed in practice:
- Works well with ArgoCD and environment overlays — no change to the app-of-apps pattern, just a `path:` change per Application.
- Better for patch-based customization and explicit YAML review — every env var and probe is now plain YAML, not hidden behind `{{ .Values.x }}`.
- Lost Helm templating: each service's `overlays/dev/<service>/kustomization.yaml` is currently near-identical (base pointer + image tag). A `stage`/`prod` overlay will introduce real patches (replica counts, resource limits) — that's the point where the repetition Helm used to hide becomes visible and needs managing via `patches:`.

Current structure: `kustomize/base/<service>` (core) and `kustomize/workers/<worker>` (KEDA workers), consumed by `kustomize/overlays/dev/<service>`. See `kustomize/README.md` for the full layout and migration notes, including a tracing env-var bug found and fixed during the port.

## Release Hardening Backlog (DevOps)
- ~~Replace latest tags with immutable tags~~ — done 2026-07-08. Every build now pushes a `${{ github.sha }}` tag to ACR and bumps the corresponding kustomize overlay; `latest` is still pushed alongside it for convenience (`docker pull` debugging) but nothing deploys off it.
- ~~Add automated image update workflow~~ — done 2026-07-08, via the tag-bump-and-commit step in each workflow (not a separate promotion PR — direct commit to `main`, matching this repo's existing "push to main deploys" model). A PR-based promotion flow is still open if/when a stage/prod split is added.
- The tag-bump commit pushes straight to `main` with no review step. Fine for a single dev environment; revisit once a stage/prod promotion flow exists (see Infra backlog).
- Add platform validation workflow: helm/kustomize render checks, kubeconform, policy checks.
- Add Terraform quality workflow: fmt, validate, tflint, tfsec/checkov.
- Pin GitHub Actions to stable versions instead of floating refs.

## Standards Checklist
- Every deployment is reproducible from git commit + image digest.
- Environment promotion is controlled and auditable.
- GitOps app boundaries are environment-safe.
- Rollback procedure is documented and tested.
- Pipeline fails fast on security and policy violations.
