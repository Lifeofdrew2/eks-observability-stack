# Service level objective and alerting approach

## SLO

| | |
|---|---|
| **SLI** | Proportion of HTTP requests to demo-api that do **not** return a 5xx status |
| **Objective** | 99.9% over a rolling 30 days |
| **Error budget** | 0.1% of requests (≈ 43 minutes of full outage per month) |

Latency is tracked as a separate signal (p95 < 500ms) with a warning alert.

## Why burn-rate alerts instead of "error rate > X%"

A fixed threshold either pages for short blips that don't threaten the SLO
or stays quiet during a slow leak that does. Burn rate asks a better
question: *how fast are we spending the error budget?*

| Alert | Long window | Short window | Burn rate | Budget spent before it fires | Action |
|---|---|---|---|---|---|
| `DemoApiErrorBudgetFastBurn` | 1h | 5m | 14.4x | 2% | **Page** (critical) |
| `DemoApiErrorBudgetSlowBurn` | 6h | 30m | 6x | 5% | **Ticket** (warning) |

- The **long window** proves the problem is significant.
- The **short window** makes the alert stop quickly once the problem is fixed.

This is the multi-window, multi-burn-rate method described in the Google SRE Workbook.

## Signals by layer

| Layer | Source | Where it shows up |
|---|---|---|
| Application (RED: rate, errors, duration) | App `/metrics` → Prometheus | Grafana "Service Overview", app alerts |
| Kubernetes workload | kube-state-metrics → Prometheus | Restart / replica / HPA alerts |
| Nodes | node-exporter → Prometheus; Container Insights → CloudWatch | Grafana "Node Resources", CloudWatch alarms |
| Load balancer | ALB metrics → CloudWatch | CloudWatch dashboard, 5xx and latency alarms |
| Logs | Fluent Bit → CloudWatch Logs | `/aws/containerinsights/<cluster>/application` |

## Why both Prometheus and CloudWatch

- **Prometheus/Grafana** give high-resolution application metrics, PromQL,
  SLO maths and alert unit tests, all version-controlled.
- **CloudWatch** sees what Prometheus cannot from inside the cluster (the ALB,
  AWS-managed control plane), keeps working if the cluster itself is
  unhealthy, and integrates with SNS, AWS Chatbot and Incident Manager.
