# SRE README

Scope: reliability, observability, alerting, incident readiness, and operational excellence.

## Change Highlights
- 2026-06-04: Initial SRE README created from main project README.
- 2026-06-04: Added SRE-first 2-week priority plan integrated with infra and DevOps.
- 2026-07-09: Wired `loadgenerator` into the platform — `kustomize/base/loadgenerator` (CronJob, suspended by default, weekly schedule if enabled), its own ArgoCD app, a CI workflow, and a focused exercise doc at `README02/game-day-service-bus-backlog.md`. Trigger on demand with `kubectl create job --from=cronjob/loadgenerator-gameday`. Closes the SRE Week 2 backlog item; still fully manual/observed, no automated pass/fail assertion yet (see doc's "Known gap").
- 2026-07-08: Added `kubernetes-platform/observability/prometheus/alerts.yaml` (PrometheusRule, auto-deployed by the existing `prometheus-monitors` ArgoCD app). Two real alerts live now: sustained Service Bus backlog per worker (`keda_scaler_metrics_value`) and pod crash-loop/OOMKill (`kube-state-metrics`). **Checkout availability and checkout latency SLOs are still not alertable** — no service emits request-count/duration metrics to Prometheus today (only traces, to App Insights). See the alerts file header for what's needed to unblock those two. Also added: default-deny NetworkPolicies + per-service allow rules (`kubernetes-platform/network-policies/` + one `networkpolicy.yaml` per service kustomize base), PodDisruptionBudgets on all 10 core services, and Key Vault + CSI-driven Redis secret (replacing the manual `kubectl create secret` step) — see DevOps-README.md and Infra-README.md for details on those.

## SRE Goals For This Platform
- Maintain reliable checkout and browsing experience.
- Detect failures early using metrics, traces, and logs.
- Provide clear runbooks and actionable alerts.
- Control cost while preserving reliability.

## Observability Stack
- Metrics: Prometheus
- Dashboards: Grafana
- Traces/Logs pipeline: OpenTelemetry Collector -> Application Insights
- Alerting: Alertmanager (via kube-prometheus stack)

## Why gRPC Is Used In This Project
Many service-to-service paths use gRPC because it is:
- Efficient (binary protocol over HTTP/2).
- Strongly typed (proto contracts reduce drift).
- Good for low-latency internal communication.
- Well-suited for polyglot microservices used here.

Also, OTEL telemetry export uses OTLP over gRPC on port 4317 by default in this setup.

## Reliability Signals To Track First
- Checkout success rate
- p95 and p99 end-to-end checkout latency
- Service Bus queue depth per worker subscription
- KEDA desired vs running replicas
- Pod restart rate and OOM events
- Error rate by service and endpoint

## Incident Response Minimum
- Severity matrix (SEV1/SEV2/SEV3)
- On-call ownership and escalation path
- Triage checklist for queue backlog, pod failures, and dependency outages
- Post-incident review template with action items

## Suggested 2-Week Priority Plan (SRE Embedded)
### Week 1 (SRE + Foundation)
1. Define 3 initial SLOs (checkout availability, checkout latency, queue processing lag). — done, though 2 of 3 aren't measurable yet (see 2026-07-08 changelog).
2. ~~Create alert rules tied to those SLOs~~ — done for queue processing lag + pod health; availability/latency blocked on missing request metrics.
3. ~~Replace mutable image tags with immutable tags in delivery flow~~ — done 2026-07-08 (see DevOps-README.md).
4. ~~Add health probes and baseline securityContext to all workloads~~ — done as part of the Kustomize migration (2026-07-07).
5. Add platform CI checks (render/validate/policy/security) — still open.

### Week 2 (SRE + Production Controls)
1. Add dev/stage/prod overlays and promotion flow — still open.
2. ~~Add NetworkPolicy default-deny plus explicit allow rules~~ — done 2026-07-08.
3. Add ResourceQuota and LimitRange by namespace — still open (distinct from PDBs, which are done).
4. Add Terraform remote state backend and add stage environment — backend is scaffolded but not activated (see Infra-README.md); stage environment still open.
5. ~~Run one controlled game day (Service Bus backlog and worker recovery)~~ — mechanism is done 2026-07-09 (`README02/game-day-service-bus-backlog.md`); actually *running* it against a live cluster and recording results is still open.

## SRE Standards Checklist
- SLOs are documented and measured.
- Alerts map to user impact and have runbooks.
- Dashboards exist for golden signals and queue health.
- Error budget policy is defined for releases.
- At least one reliability drill is run each month.
