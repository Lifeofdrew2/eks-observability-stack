# Runbooks

Every alert links here through its `runbook_url` annotation.
Commands assume the `demo` namespace; adjust for `demo-staging` / `demo-production`.

---

## DemoApiUnavailable
**Meaning:** Prometheus cannot scrape any healthy demo-api pod.
**Check:**
```bash
kubectl -n demo get pods -l app.kubernetes.io/name=demo-api -o wide
kubectl -n demo describe deployment demo-api | tail -20
kubectl -n demo get events --sort-by=.lastTimestamp | tail -20
```
**Common causes:** crash loop after a bad deploy; image pull failure; nodes
not ready; NetworkPolicy blocking the scrape.
**Fix:** if it started with a deployment, roll back
(`kubectl -n demo rollout undo deployment/demo-api`), then investigate.

## DemoApiErrorBudgetFastBurn
**Meaning:** at least 1.44% of requests are failing — the monthly budget will be gone in about 2 days.
**Check:** Grafana → *demo-api / Service Overview* → "Responses by status code" and "Request rate by route" to find which route fails.
```bash
kubectl -n demo logs -l app.kubernetes.io/name=demo-api --since=15m | grep -i error | tail -50
kubectl -n demo rollout history deployment/demo-api
```
**Fix:** a recent deploy is the usual cause — roll back first, debug second.

## DemoApiErrorBudgetSlowBurn
**Meaning:** a smaller but sustained error rate (> 0.6% for hours).
**Action:** not urgent; open a ticket. Look for a single failing route or dependency.

## DemoApiHighLatency
**Meaning:** p95 latency above 500ms for 10 minutes.
**Check:** "p95 latency by route" panel; CPU throttling and HPA status:
```bash
kubectl -n demo top pods -l app.kubernetes.io/name=demo-api
kubectl -n demo get hpa demo-api
```
**Fix:** if pods are CPU-bound and the HPA is at max, raise `maxReplicas` or the CPU limit.

## DemoApiPodRestarting
```bash
kubectl -n demo logs <pod> --previous
kubectl -n demo describe pod <pod> | grep -A5 "Last State"
```
`OOMKilled` → raise the memory limit. Liveness failures → check `/healthz` and startup time.

## DemoApiReplicasUnavailable
```bash
kubectl -n demo get pods -l app.kubernetes.io/name=demo-api
kubectl -n demo describe pod <pending-pod> | tail -20
```
`Pending` with "didn't match pod topology spread constraints" or "Insufficient cpu" → nodes are full or an AZ has no nodes; check the node group.

## DemoApiAutoscalerAtMax
The HPA wants more pods than `maxReplicas`. Confirm the traffic is genuine, then raise `maxReplicas` and make sure the node group `max_size` can fit them.

## NodeHighCpu / NodeHighMemory
```bash
kubectl top nodes
kubectl top pods -A --sort-by=cpu | head    # or --sort-by=memory
```
Sustained high usage across all nodes → increase node group `desired_size`/`max_size`. One noisy pod → check its requests and limits.

## NodeDiskAlmostFull
Usually container images or logs. Kubelet garbage-collects images at 85% by default; if it keeps climbing, increase the node volume size in the node group.
