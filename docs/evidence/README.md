# Evidence

| File | What it shows |
|---|---|
| [fast-burn-alert-timeline.png](fast-burn-alert-timeline.png) | Chart of the recorded incident: error ratio, when the alert went pending, fired and resolved |
| [e2e-alerting-run.txt](e2e-alerting-run.txt) | Raw log of that run: scrape targets up, alert states every 15s, notifications received, and all 26 dashboard queries returning data |
| [offline-validation.txt](offline-validation.txt) | Full output of `./scripts/verify.sh`: rule syntax, alert unit tests, config checks, manifests, Terraform |

## What the end-to-end run shows

| Time after errors start | Event |
|---|---|
| ~1 min | 5m error ratio crosses the 1.44% fast-burn threshold; alert goes **pending** |
| ~3 min 15 s | Alert **fires**; Alertmanager routes it to the `pages` (critical) receiver |
| 3 min 45 s | Errors stopped |
| ~8 min | 5m window drops below threshold; alert **resolves** and a RESOLVED notification is sent, even though the 1h window is still elevated |

Grafana screenshots and in-cluster (EKS) evidence are added here after a live run; see [../validation.md](../validation.md).
