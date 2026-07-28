#!/usr/bin/env bash
# load_ontology.sh — Load TBox ontology and demo data into Fuseki
# Usage: bash load_ontology.sh [demo-name]
#   demo-name: sim-activation | git-push-safety | (empty = ontology only)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Load config
if [[ -f "${PROJECT_DIR}/engine/config.env" ]]; then
    source "${PROJECT_DIR}/engine/config.env"
else
    source "${PROJECT_DIR}/engine/config.env.example"
fi

DEMO_NAME="${1:-}"

info() { echo "  [+] $*"; }
ok()   { echo "  [✓] $*"; }
fail() { echo "  [✗] $*" >&2; exit 1; }

load_turtle() {
    local file="$1" graph="$2" label="$3"
    if [[ ! -f "$file" ]]; then
        fail "File not found: $file"
    fi
    local http_code
    http_code=$(curl -s -o /dev/null -w '%{http_code}' \
        -X POST "${GSP_URL}?graph=${graph}" \
        -H "Content-Type: text/turtle" \
        --data-binary @"$file")
    if [[ "$http_code" == "200" || "$http_code" == "201" || "$http_code" == "204" ]]; then
        ok "${label} → ${graph} (HTTP ${http_code})"
    else
        fail "${label} → ${graph} (HTTP ${http_code})"
    fi
}

echo "══════════════════════════════════════════════════════"
echo "  Loading Ontology into Fuseki"
echo "══════════════════════════════════════════════════════"
echo ""

# Check Fuseki is running
HTTP_CODE=$(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 2 \
    "${FUSEKI_HOST}/\$/ping" 2>/dev/null || echo "000")
if [[ "$HTTP_CODE" != "200" ]]; then
    fail "Fuseki not running at ${FUSEKI_HOST} (HTTP ${HTTP_CODE}). Run 'fuseki start' first."
fi
ok "Fuseki is running at ${FUSEKI_HOST}"

# Check dataset exists, create if not
DS_CHECK=$(curl -s "${FUSEKI_HOST}/\$/datasets" 2>/dev/null \
    | jq -r ".datasets[] | select(.\"ds.name\" == \"/${DATASET}\") | .\"ds.name\"" 2>/dev/null || echo "")

if [[ -z "$DS_CHECK" ]]; then
    info "Creating dataset /${DATASET}..."
    http_code=$(curl -s -o /dev/null -w '%{http_code}' \
        -X POST "${FUSEKI_HOST}/\$/datasets" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        --data "dbName=${DATASET}&dbType=mem")
    if [[ "$http_code" == "200" || "$http_code" == "201" ]]; then
        ok "Dataset /${DATASET} created"
    else
        fail "Failed to create dataset (HTTP ${http_code})"
    fi
else
    ok "Dataset /${DATASET} exists"
fi

echo ""

# ── Load TBox (ontology schemas) ──────────────────────
info "Loading TBox ontology into definitions graph..."
load_turtle "${PROJECT_DIR}/ontology/sbpmn.ttl" "$DEFINITIONS_GRAPH" "sbpmn.ttl"
load_turtle "${PROJECT_DIR}/ontology/cto.ttl" "$DEFINITIONS_GRAPH" "cto.ttl"
load_turtle "${PROJECT_DIR}/ontology/agentflow.ttl" "$DEFINITIONS_GRAPH" "agentflow.ttl"

# ── Load Demo Data (if specified) ─────────────────────
if [[ -n "$DEMO_NAME" ]]; then
    DEMO_DIR="${PROJECT_DIR}/demo/${DEMO_NAME}"
    if [[ ! -d "$DEMO_DIR" ]]; then
        fail "Demo directory not found: ${DEMO_DIR}"
    fi
    echo ""
    info "Loading demo: ${DEMO_NAME}"

    if [[ -f "${DEMO_DIR}/definitions.ttl" ]]; then
        load_turtle "${DEMO_DIR}/definitions.ttl" "$DEFINITIONS_GRAPH" "${DEMO_NAME}/definitions.ttl"
    fi

    if [[ -f "${DEMO_DIR}/runtime.ttl" ]]; then
        load_turtle "${DEMO_DIR}/runtime.ttl" "$RUNTIME_GRAPH" "${DEMO_NAME}/runtime.ttl"
    fi
fi

echo ""

# ── Verify loaded triples ─────────────────────────────
info "Verifying loaded triples..."

DEF_COUNT=$(curl -s -X POST "${QUERY_URL}" \
    -H "Content-Type: application/sparql-query" \
    -H "Accept: application/sparql-results+json" \
    --data "SELECT (COUNT(*) AS ?c) WHERE { GRAPH <${DEFINITIONS_GRAPH}> { ?s ?p ?o } }" \
    | jq -r '.results.bindings[0].c.value' 2>/dev/null || echo '0')

RT_COUNT=$(curl -s -X POST "${QUERY_URL}" \
    -H "Content-Type: application/sparql-query" \
    -H "Accept: application/sparql-results+json" \
    --data "SELECT (COUNT(*) AS ?c) WHERE { GRAPH <${RUNTIME_GRAPH}> { ?s ?p ?o } }" \
    | jq -r '.results.bindings[0].c.value' 2>/dev/null || echo '0')

echo "  Definitions graph: ${DEF_COUNT} triples"
echo "  Runtime graph:     ${RT_COUNT} triples"

echo ""
echo "══════════════════════════════════════════════════════"
echo "  Load Complete"
echo "══════════════════════════════════════════════════════"
