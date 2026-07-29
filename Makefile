# AgentFLOW — Graph-Driven Agent Orchestrator
# Usage: make <target>

SHELL := /bin/bash

# Load config
-include engine/config.env

.PHONY: check load validate clean demo-telecom demo-git-push approve

check: ## Verify prerequisites
	@bash scripts/check_prerequisites.sh 2>/dev/null || \
	 echo 'Run: bash scripts/check_prerequisites.sh'

load: ## Load ontology into Fuseki (usage: make load DEMO=sim-activation)
	@bash scripts/load_ontology.sh $(DEMO)

validate: ## Validate ontology syntax
	@export PATH="$$HOME/.local/share/apache-jena/bin:$$PATH" && \
	 for f in ontology/*.ttl ontology/shapes/*.ttl; do \
	   riot --validate "$$f" 2>&1 && echo "  ✅ $$f" || echo "  ❌ $$f"; \
	 done

clean: ## Remove runtime data from Fuseki and temp files
	@curl -s -X DELETE "$(FUSEKI_HOST)/\$$/datasets/$(DATASET)" > /dev/null 2>&1 || true
	@rm -f /tmp/agentflow_*.log /tmp/agentflow_*.json
	@echo '✓ Dataset cleared, temp files removed'

demo-telecom: ## Run SIM Activation demo
	@$(MAKE) clean
	@bash scripts/load_ontology.sh sim-activation
	@echo ''
	@bash engine/orchestrate.sh --demo demo/sim-activation

demo-git-push: ## Run Git Push Safety demo (interactive)
	@$(MAKE) clean
	@bash scripts/load_ontology.sh git-push-safety
	@echo ''
	@bash engine/orchestrate.sh --demo demo/git-push-safety

approve: ## Inject approval decision (usage: make approve PROCESS=ProcInst_GitPush_001 VALUE=APPROVED)
	@curl -s -o /dev/null -w 'HTTP %{http_code}\n' \
	  -X POST "$(FUSEKI_HOST)/$(DATASET)/update" \
	  -H "Content-Type: application/sparql-update" \
	  --data "PREFIX agentflow: <http://example.org/ontology/agentflow#> \
	    PREFIX ex: <http://example.org/instances/> \
	    INSERT DATA { \
	      GRAPH <$(RUNTIME_GRAPH)> { \
	        _:approval a agentflow:ProcessVariable ; \
	          agentflow:varName \"approval_status\" ; \
	          agentflow:varValue \"$(VALUE)\" . \
	        ex:$(PROCESS) agentflow:hasVariable _:approval . \
	      } \
	    }"
	@echo '✓ Approval set: $(VALUE) for $(PROCESS)'

test: ## Run all tests (needs Fuseki + Goose)
	@bash tests/run_all.sh all

test-fast: ## Syntax + namespace checks only (no Fuseki needed)
	@bash tests/run_all.sh fast

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
	  sed 's/Makefile://' | \
	  awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

.DEFAULT_GOAL := help
