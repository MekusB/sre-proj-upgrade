# Game Day: Service Bus Backlog + Worker Recovery

Scope: one exercise, validating that a real checkout traffic spike produces a Service Bus backlog, KEDA scales workers 0→N in response, the `ServiceBusBacklogSustained` alert fires if that backlog persists, and workers drain it back down.

## What this proves

- `checkoutservice` actually publishes to `checkout-events` under load, not just in the happy-path single-request case.
- KEDA's `ScaledObject`s (`kustomize/workers/*/scaledobject.yaml`) react to real queue depth, not just the demo scenario used during initial setup.
- The `ServiceBusBacklogSustained` alert (`kubernetes-platform/observability/prometheus/alerts.yaml`) fires when it should and clears when it should.
- Workers scale back to 0 once the backlog drains — confirming there's no stuck-consumer or scaling-down failure mode.

## Prerequisites

- `loadgenerator` image exists in ACR (push to `services/loadgenerator/**` on `main` triggers `build-loadgenerator.yml`, or trigger it manually via *Actions → Build LoadGenerator Image → Run workflow*).
- ArgoCD has synced the `loadgenerator` Application (`kubectl get application loadgenerator -n argocd`).
- Grafana `sre-platform` dashboard is imported (see main `README.md` → SRE Platform Dashboard).

## Run it

The CronJob (`loadgenerator-gameday`, `core` namespace) is `suspend: true` by default — it does not run on its own. Trigger it on demand:

```bash
kubectl create job --from=cronjob/loadgenerator-gameday -n core gameday-$(date +%s)
```

This runs 50 simulated users against `frontend` for 10 minutes (`LOCUST_RUN_TIME=10m`), weighted so roughly 1 in 18 requests is a full checkout — enough volume over 10 minutes to push real messages through `checkout-events`.

To make it a recurring exercise instead of one-off: set `suspend: false` in `kustomize/base/loadgenerator/cronjob.yaml` (runs weekly, Monday 09:00 UTC) and let ArgoCD sync it.

## Watch, in order

1. **Queue Depth (current)** panel, Grafana — should climb above 0 within the first couple minutes as checkout volume outpaces a single idle worker replica.
2. **Worker Replicas — Desired vs Running** panel — `payment-worker`/`email-worker`/`shipping-worker` should scale up from 0 as KEDA's `pollingInterval: 10` picks up the queue metric (`keda_scaler_metrics_value`).
3. Alertmanager / Grafana alert view — if the backlog stays above 20 for 10 minutes straight, `ServiceBusBacklogSustained` fires (`severity: warning`). With only 50 users this may or may not cross that threshold — that's a legitimate data point, not a failure; adjust `USERS`/`RATE` in `cronjob.yaml` to push harder if you want to guarantee it fires.
4. **Pod Restarts** / **CPU Usage** / **Memory Usage** panels — confirm workers don't crash-loop or hit their resource limits under the scale-up (limits are in each worker's `kustomize/workers/*/deployment.yaml`).
5. After the job completes (10 min) and the queue drains, **Worker Replicas** should return to 0 and stay there — KEDA's `cooldownPeriod: 60` on each `ScaledObject` controls how fast that happens.

## Success criteria

- Queue depth visibly rises and falls — not flat (traffic reached checkout) and not stuck high (workers kept up).
- Worker replicas scale up within ~1 minute of backlog appearing, and back to 0 within ~1-2 minutes of it clearing.
- No pod restarts/OOMKills during the run.
- If the alert fired, it resolves on its own once the backlog clears — no manual Alertmanager silence needed.

## Cleanup

```bash
kubectl delete job -n core -l app=loadgenerator
```

The CronJob itself stays (suspended) for the next run.

## Known gap

There's no automated pass/fail check here — this is a manual, observed exercise. Turning "queue depth rose and fell, workers scaled and recovered, no restarts" into an automated assertion (e.g. a follow-up script querying Prometheus after the job completes) is a reasonable next step if this becomes a recurring CI-gated exercise rather than an occasional manual one.
