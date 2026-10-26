# Validation

## Rule and config checks

| Check | Tool | Result |
|---|---|---|
| Rule syntax (17 rules in 4 files) | `promtool check rules` (Prometheus 3.15) | ✅ pass |
| Alert unit tests (6 scenarios) | `promtool test rules` | ✅ pass |
| Prometheus config | `promtool check config` | ✅ pass |
| Alertmanager routing and inhibition | `amtool check-config` (0.34) | ✅ pass |
| Generated PrometheusRules / dashboard ConfigMaps | kubeconform with CRD schemas | ✅ 6/6 valid |
| Generated files in sync with sources | `render_k8s.py --check` | ✅ |
| Dashboard PromQL (26 queries) | parsed by promtool | ✅ all valid |
| Helm values keys | compared with kube-prometheus-stack 92.13.1 `values.yaml` | ✅ all present (Grafana keys belong to its sub-chart) |
| CloudWatch Terraform | fmt + validate (AWS provider v6) | ✅ valid |
| Docker Compose file | `docker compose config` | ✅ valid |
| Workflow | actionlint | ✅ pass |

### Alert unit tests

| Scenario | Expected | Result |
|---|---|---|
| All targets down | `DemoApiUnavailable` pending at 30s, firing at 3m | ✅ |
| 1 of 2 targets down | No page | ✅ |
| 5% errors | `DemoApiErrorBudgetFastBurn` fires; 5m error ratio = 0.05 | ✅ |
| 0.05% errors (inside budget) | No fast or slow burn alert | ✅ |
| p95 ≈ 975ms | `DemoApiHighLatency` pending at 8m, firing at 20m | ✅ |
| Node memory 95% | `NodeHighMemory` fires | ✅ |

## End-to-end run

The app, node_exporter, Prometheus 3.15 and Alertmanager 0.34 were run
together with the load generator and this repository's unmodified rules:

- All 3 scrape targets healthy; recording rules produced data within one evaluation.
- **All 26 dashboard queries returned data** (both dashboards).
- Raising the error rate to 25% moved `DemoApiErrorBudgetFastBurn` from
  pending to **firing in about 3 minutes**, and Alertmanager delivered it to the
  `pages` receiver (critical route).
- Dropping the error rate to 0 cleared the short (5m) window, so the alert
  resolved about 5 minutes later — even though the 1h window was still
  elevated — and Alertmanager sent the RESOLVED notification. This is the
  intended multi-window behaviour.

Not yet verified: Grafana rendering of the two dashboards (run `make up` and
open the *Demo Platform* folder), and the in-cluster install on EKS.

## Live EKS checklist

- [ ] `kubectl -n monitoring get pods` – all Running
- [ ] Prometheus *Targets* page shows `serviceMonitor/monitoring/demo-api` up
- [ ] Grafana *Demo Platform* folder shows both dashboards with data
- [ ] CloudWatch → Container Insights shows the cluster; log groups receive logs
- [ ] SNS email subscription confirmed; a test alarm arrives
      (`aws cloudwatch set-alarm-state --alarm-name <name> --state-value ALARM --state-reason test`)
