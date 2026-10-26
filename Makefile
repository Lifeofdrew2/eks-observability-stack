COMPOSE = docker compose -f local/docker-compose.yml

.PHONY: help up down logs alerts-demo calm test render install-k8s

help:          ## Show available targets
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-12s %s\n", $$1, $$2}'

up:            ## Start the local stack (Grafana on :3000, Prometheus on :9090)
	$(COMPOSE) up -d --build

down:          ## Stop the local stack
	$(COMPOSE) down

logs:          ## Follow alert notifications as they arrive
	$(COMPOSE) logs -f webhook-sink

alerts-demo:   ## Push the error rate to 20% so the burn-rate alerts fire (~3-5 min)
	ERROR_RATE=0.2 $(COMPOSE) up -d loadgen

calm:          ## Return to normal traffic so alerts resolve
	ERROR_RATE=0.01 $(COMPOSE) up -d loadgen

test:          ## Validate rules, run alert unit tests, check configs
	promtool check rules prometheus/rules/*.yml
	promtool test rules prometheus/tests/*.yml
	amtool check-config alertmanager/alertmanager.yml
	python3 scripts/render_k8s.py --check

render:        ## Regenerate kubernetes/generated/ from rules and dashboards
	python3 scripts/render_k8s.py

install-k8s:   ## Install kube-prometheus-stack + rules + dashboards into EKS
	./scripts/install-k8s.sh
