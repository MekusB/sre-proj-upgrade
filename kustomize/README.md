# Kustomize — SRE Platform (Azure)

This is the Azure-native Kustomize tree for this platform's 10 core services and 3 KEDA workers. It replaced the Helm charts under `helm/` as the source ArgoCD deploys from (see `kubernetes-platform/argocd/apps/*.yaml`, each `spec.source.path` points at `kustomize/overlays/dev/<service>`).

## Layout

```
kustomize/
├── base/<service>/            # 10 core services: deployment, service, serviceaccount
├── workers/<worker>/          # 3 KEDA workers: deployment, serviceaccount, scaledobject, trigger-auth
├── overlays/dev/<service>/    # one overlay per service/worker — sets image tag, references base or workers
└── components/network-policies/  # not yet wired into any overlay — see backlog below
```

Each `overlays/dev/<name>/kustomization.yaml` is intentionally thin today (just a `resources:` pointer + an `images:` tag override). That's the seam for adding a `stage`/`prod` overlay later: same base, different replica counts / resource limits / image tags via `patches:`.

## Validate a build without a cluster

```bash
kubectl kustomize kustomize/overlays/dev/<service>
```

## Notes from the Helm→Kustomize migration

- Workers reuse their parent service's image with `WORKER_MODE=true` (not a separate binary) — see `services/<service>/worker.go|index.js|email_server.py`.
- `azure.workload.identity/client-id` annotations on `checkoutservice-sa`, `cartservice-sa`, `productcatalogservice-sa`, and all 3 worker SAs are copied from the currently-provisioned Terraform managed identities (`terraform output worker_client_ids`). If you re-provision those identities, update the annotation in the corresponding `base/<service>/serviceaccount.yaml` or `workers/<worker>/serviceaccount.yaml`.
- Tracing env var was corrected during the migration: `paymentservice`, `currencyservice`, `recommendationservice`, `emailservice`, and both `payment-worker`/`email-worker` now use `COLLECTOR_SERVICE_ADDR`, matching what their source actually reads (the old Helm charts set `OTEL_EXPORTER_OTLP_ENDPOINT`, which none of those services consume — tracing was silently a no-op for 5 of 10 services). `shippingservice`/`shipping-worker`, `adservice`, and `cartservice` have no tracing implementation in source at all, so no OTLP env var is set for them — that's a real gap, not an oversight, if you want traces from those three.

## Backlog

- Wire `components/network-policies` into the dev overlays (default-deny + explicit allow per service).
- `cartservice-sa` currently has a workload-identity annotation and a Service Bus RBAC grant (in Terraform) despite `cartservice` never calling Service Bus in source — worth removing for least-privilege.
- Image tags are `latest` everywhere; the `images:` block in each overlay is the place to switch to immutable tags once CI is updated to pass a git SHA.

## Registry (2026-07-08)

Every overlay's `images:` block sets `newName: srecoreacr.azurecr.io/<service>`, replacing Docker Hub (`jukpozi/*`). CI (`.github/workflows/build-*.yml`) now pushes there directly and bumps `newTag:` in the relevant overlay(s) on every build — see `README02/DevOps-README.md` for the exact flow and the required GitHub repo secrets.
