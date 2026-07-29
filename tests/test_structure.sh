#!/usr/bin/env bash
# test_structure.sh — Verify ontology structure via SPARQL queries against Fuseki
# Requires: Fuseki running with data loaded
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

if [[ -f "${PROJECT_DIR}/engine/config.env" ]]; then
    source "${PROJECT_DIR}/engine/config.env"
else
    source "${PROJECT_DIR}/engine/config.env.example"
fi

PASS=0
FAIL=0

sparql_ask() {
    local query="$1"
    local result
    result=$(curl -s -X POST "${QUERY_URL}" \
        -H "Content-Type: application/sparql-query" \
        -H "Accept: application/sparql-results+json" \
        --data "$query" 2>/dev/null)
    echo "$result" | jq -r '.boolean // empty' 2>/dev/null
}

sparql_count() {
    local query="$1"
    local result
    result=$(curl -s -X POST "${QUERY_URL}" \
        -H "Content-Type: application/sparql-query" \
        -H "Accept: application/sparql-results+json" \
        --data "$query" 2>/dev/null)
    echo "$result" | jq -r '.results.bindings | length' 2>/dev/null
}

assert_ask_true() {
    local id="$1" label="$2" query="$3"
    local result
    result=$(sparql_ask "$query")
    if [[ "$result" == "true" ]]; then
        printf '  ✅ %s: %s\n' "$id" "$label"
        PASS=$((PASS + 1))
    else
        printf '  ❌ %s: %s (expected true, got %s)\n' "$id" "$label" "$result"
        FAIL=$((FAIL + 1))
    fi
}

assert_count_zero() {
    local id="$1" label="$2" query="$3"
    local result
    result=$(sparql_count "$query")
    if [[ "$result" == "0" ]]; then
        printf '  ✅ %s: %s\n' "$id" "$label"
        PASS=$((PASS + 1))
    else
        printf '  ❌ %s: %s (expected 0, got %s)\n' "$id" "$label" "$result"
        FAIL=$((FAIL + 1))
    fi
}

assert_count_gte() {
    local id="$1" label="$2" min="$3" query="$4"
    local result
    result=$(sparql_count "$query")
    if [[ "$result" -ge "$min" ]]; then
        printf '  ✅ %s: %s (count: %s)\n' "$id" "$label" "$result"
        PASS=$((PASS + 1))
    else
        printf '  ❌ %s: %s (expected >= %s, got %s)\n' "$id" "$label" "$min" "$result"
        FAIL=$((FAIL + 1))
    fi
}

# Check Fuseki is running
HTTP_CODE=$(curl -s -o /dev/null -w '%{http_code}' "${FUSEKI_HOST}/\$/ping" 2>/dev/null || echo '000')
if [[ "$HTTP_CODE" != "200" ]]; then
    echo '❌ Fuseki is not running. Start it first: fuseki start'
    exit 1
fi

# Check dataset has data
DEF_COUNT=$(sparql_count "SELECT ?s WHERE { GRAPH <${DEFINITIONS_GRAPH}> { ?s ?p ?o } } LIMIT 1")
if [[ "$DEF_COUNT" == "0" ]]; then
    echo '❌ No data in definitions graph. Load ontology first: make load DEMO=sim-activation'
    exit 1
fi

echo '══════════════════════════════════════════════════════'
echo '  Test: Ontology Structure (SPARQL)'
echo '══════════════════════════════════════════════════════'
echo ''

# Load data before running structure tests
echo '  [+] Loading ontology for structure tests...'
bash "${PROJECT_DIR}/scripts/load_ontology.sh" sim-activation > /dev/null 2>&1

# Use the prefixes from our ontology
PREFIX='
PREFIX sbpmnc:    <https://sBPMN.github.io/2.0/classes#>
PREFIX sbpmn:     <https://sBPMN.github.io/2.0/properties#>
PREFIX agentflow: <http://example.org/ontology/agentflow#>
PREFIX rdfs:      <http://www.w3.org/2000/01/rdf-schema#>
PREFIX owl:       <http://www.w3.org/2002/07/owl#>
'

echo '── Process Topology ─────────────────────────────────'

assert_ask_true 'S-01' 'Process has at least one StartEvent' "
${PREFIX}
ASK {
  GRAPH <${DEFINITIONS_GRAPH}> {
    ?start a sbpmnc:startEvent .
    ?start agentflow:nextTask ?next .
  }
}"

assert_ask_true 'S-02' 'Process has at least one EndEvent' "
${PREFIX}
ASK {
  GRAPH <${DEFINITIONS_GRAPH}> {
    ?end a sbpmnc:endEvent .
  }
}"

assert_count_zero 'S-03' 'Every AgenticTask has a recipe' "
${PREFIX}
SELECT ?task WHERE {
  GRAPH <${DEFINITIONS_GRAPH}> {
    ?task a agentflow:AgenticTask .
    FILTER NOT EXISTS { ?task agentflow:recipe ?r }
  }
}"

echo ''
echo '── Gateway Structure ────────────────────────────────'

# Check gateways have >= 2 outgoing edges
# Find gateways with fewer than 2 outgoing edges (should be zero)
assert_count_zero 'S-04' 'Every Gateway has >= 2 outgoing edges' "
${PREFIX}
SELECT ?gw WHERE {
  GRAPH <${DEFINITIONS_GRAPH}> {
    ?gw a ?gwType .
    FILTER (?gwType IN (sbpmnc:exclusiveGateway, agentflow:GuardrailGateway))
    {
      SELECT ?gw (COUNT(?target) AS ?edgeCount) WHERE {
        GRAPH <${DEFINITIONS_GRAPH}> {
          ?gw agentflow:nextTask ?target .
        }
      } GROUP BY ?gw
    }
    FILTER (?edgeCount < 2)
  }
}"

echo ''
echo '── Runtime State ────────────────────────────────────'

assert_ask_true 'S-05' 'Process instance exists in runtime graph' "
${PREFIX}
ASK {
  GRAPH <${RUNTIME_GRAPH}> {
    ?proc a agentflow:ProcessInstance .
    ?proc agentflow:processStatus ?status .
  }
}"

assert_ask_true 'S-06' 'Process instance has currentTask' "
${PREFIX}
ASK {
  GRAPH <${RUNTIME_GRAPH}> {
    ?proc a agentflow:ProcessInstance .
    ?proc agentflow:currentTask ?task .
  }
}"

assert_ask_true 'S-07' 'Process instance has variables' "
${PREFIX}
ASK {
  GRAPH <${RUNTIME_GRAPH}> {
    ?proc a agentflow:ProcessInstance .
    ?proc agentflow:hasVariable ?var .
    ?var agentflow:varName ?name .
    ?var agentflow:varValue ?value .
  }
}"

echo ''
echo '══════════════════════════════════════════════════════'
if [[ $FAIL -eq 0 ]]; then
    echo "  Structure: $PASS passed, 0 failed ✅"
else
    echo "  Structure: $PASS passed, $FAIL FAILED ❌"
fi
echo '══════════════════════════════════════════════════════'

[[ $FAIL -eq 0 ]] || exit 1
