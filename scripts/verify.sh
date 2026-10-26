#!/usr/bin/env bash
# Run every offline check for this repository (no AWS account needed).
# Requires: python3 (pyyaml), promtool, amtool, terraform, kubeconform, actionlint, docker compose
# Usage: ./scripts/verify.sh | tee docs/evidence/offline-validation.txt
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
TF="${TF:-terraform}"
failures=0

step() { echo; echo "=== $1"; }
run() { "$@"; local rc=$?; [[ $rc -eq 0 ]] && echo "--> PASS" || { echo "--> FAIL (exit $rc)"; failures=$((failures + 1)); }; }

echo "verify.sh - eks-observability-stack"
echo "date:   $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "commit: $(git rev-parse --short HEAD 2>/dev/null || echo n/a)"
echo "promtool: $(promtool --version 2>&1 | head -1)"

step "App: lint (ruff) and unit tests (pytest)"
run bash -c "cd app && ruff check . && python3 -m pytest -q -p no:cacheprovider --disable-warnings"

step "Prometheus rules: syntax"
run promtool check rules prometheus/rules/*.yml

step "Prometheus rules: alert unit tests"
run promtool test rules prometheus/tests/alerts-test.yml

step "Prometheus config"
run promtool check config --syntax-only prometheus/prometheus.yml

step "Alertmanager config"
run amtool check-config alertmanager/alertmanager.yml

step "Grafana dashboards: valid JSON"
run bash -c 'for f in grafana/dashboards/*.json; do python3 -m json.tool "$f" >/dev/null && echo "ok $f" || exit 1; done'

step "Grafana dashboards: every PromQL query parses"
run bash -c '
  t=$(mktemp -d)
  python3 - "$t/rules.yml" <<PY
import glob, json, sys, yaml
exprs = []
for f in sorted(glob.glob("grafana/dashboards/*.json")):
    for p in json.load(open(f))["panels"]:
        for t in p.get("targets", []):
            exprs.append(t["expr"].replace("\$namespace", ".*").replace("\$instance", ".*"))
yaml.safe_dump({"groups": [{"name": "dash", "rules": [{"record": f"dash:q{i}", "expr": e} for i, e in enumerate(exprs)]}]}, open(sys.argv[1], "w"))
print(f"{len(exprs)} queries")
PY
  promtool check rules "$t/rules.yml"'

step "Generated Kubernetes files are in sync with sources"
run python3 scripts/render_k8s.py --check

step "Kubernetes manifests incl. CRDs (kubeconform)"
run kubeconform -strict -summary -kubernetes-version 1.33.0 \
  -schema-location default \
  -schema-location 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json' \
  kubernetes/servicemonitor.yaml kubernetes/generated/

step "CloudWatch Terraform: fmt + validate"
run "$TF" fmt -check cloudwatch
if [[ -n "${TF_VALIDATE_CMD:-}" ]]; then
  run $TF_VALIDATE_CMD cloudwatch
else
  run bash -c "$TF -chdir=cloudwatch init -backend=false -input=false >/dev/null && $TF -chdir=cloudwatch validate"
fi

step "Docker Compose file"
run docker compose -f local/docker-compose.yml config -q

step "GitHub Actions workflow (actionlint)"
run actionlint .github/workflows/*.yml

echo
[[ $failures -eq 0 ]] && echo "RESULT: all checks passed" || echo "RESULT: $failures check(s) failed"
exit "$failures"
