#!/usr/bin/env bash
# Install the monitoring stack into the EKS cluster from aws-eks-platform.
# Requires: kubectl pointed at the cluster, helm 3.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CHART_VERSION="${CHART_VERSION:-92.13.1}"   # pin a tested kube-prometheus-stack version
GRAFANA_PASSWORD="${GRAFANA_PASSWORD:-$(openssl rand -base64 18)}"

echo "==> Installing kube-prometheus-stack $CHART_VERSION"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null
helm repo update prometheus-community >/dev/null
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  --version "$CHART_VERSION" \
  --values "$ROOT/kubernetes/kube-prometheus-stack-values.yaml" \
  --set grafana.adminPassword="$GRAFANA_PASSWORD" \
  --wait --timeout 10m

echo "==> Applying ServiceMonitor, alert rules and dashboards"
kubectl apply -f "$ROOT/kubernetes/servicemonitor.yaml"
kubectl apply -f "$ROOT/kubernetes/generated/"

cat <<EOF

Done.
  Grafana:      kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80
                user: admin   password: $GRAFANA_PASSWORD
  Prometheus:   kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 9090:9090
  Alertmanager: kubectl -n monitoring port-forward svc/kube-prometheus-stack-alertmanager 9093:9093
EOF
