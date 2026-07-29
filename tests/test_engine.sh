#!/usr/bin/env bash
# test_engine.sh — End-to-end engine smoke tests
# Requires: Fuseki running, Goose CLI available
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

# Record start time for post-test Goose session cleanup
TEST_START=$(date -u +"%Y-%m-%d %H:%M:%S")
GOOSE_DB="${HOME}/.local/share/goose/sessions/sessions.db"

sparql_value() {
    local query="$1"
    curl -s -X POST "${QUERY_URL}" \
        -H "Content-Type: application/sparql-query" \
        -H "Accept: application/sparql-results+json" \
        --data "$query" 2>/dev/null | jq -r '.results.bindings[0] // empty | to_entries[0].value.value // empty' 2>/dev/null
}

assert_eq() {
    local id="$1" label="$2" expected="$3" actual="$4"
    if [[ "$actual" == "$expected" ]]; then
        printf '  ✅ %s: %s\n' "$id" "$label"
        PASS=$((PASS + 1))
    else
        printf '  ❌ %s: %s (expected: %s, got: %s)\n' "$id" "$label" "$expected" "$actual"
        FAIL=$((FAIL + 1))
    fi
}

# Check Fuseki is running
HTTP_CODE=$(curl -s -o /dev/null -w '%{http_code}' "${FUSEKI_HOST}/\$/ping" 2>/dev/null || echo '000')
if [[ "$HTTP_CODE" != "200" ]]; then
    echo '❌ Fuseki is not running. Start it first: fuseki start'
    exit 1
fi

# Check Goose is available
if ! command -v goose &>/dev/null; then
    echo '❌ Goose CLI not found'
    exit 1
fi

PREFIX='
PREFIX sbpmn:     <https://sBPMN.github.io/2.0/properties#>
PREFIX sbpmnc:    <https://sBPMN.github.io/2.0/classes#>
PREFIX agentflow: <http://example.org/ontology/agentflow#>
'

echo '══════════════════════════════════════════════════════'
echo '  Test: Engine End-to-End'
echo '══════════════════════════════════════════════════════'

# ─── Demo 1: SIM Activation ─────────────────────────────
echo ''
echo '── Demo 1: SIM Activation ───────────────────────────'

# Clean and load
curl -s -X DELETE "${FUSEKI_HOST}/\$/datasets/${DATASET}" > /dev/null 2>&1 || true
bash "${PROJECT_DIR}/scripts/load_ontology.sh" sim-activation > /dev/null 2>&1

# Run engine
echo '  [+] Running engine...'
if bash "${PROJECT_DIR}/engine/orchestrate.sh" --demo "${PROJECT_DIR}/demo/sim-activation" > /tmp/agentflow_test_demo1.log 2>&1; then
    printf '  ✅ E-01: Engine exits cleanly (exit code 0)\n'
    PASS=$((PASS + 1))
else
    printf '  ❌ E-01: Engine failed (exit code %s)\n' "$?"
    FAIL=$((FAIL + 1))
    echo '  --- Engine output (last 20 lines) ---'
    tail -20 /tmp/agentflow_test_demo1.log | sed 's/^/  /'
    echo '  ---'
fi

# Check process completed
STATUS=$(sparql_value "
${PREFIX}
SELECT ?status WHERE {
  GRAPH <${RUNTIME_GRAPH}> {
    ?proc a agentflow:ProcessInstance .
    ?proc agentflow:processStatus ?status .
  }
}")
assert_eq 'E-02' 'Demo 1 process status is COMPLETED' 'COMPLETED' "$STATUS"

# Check tasks have outputs
TASK_COUNT=$(curl -s -X POST "${QUERY_URL}" \
    -H "Content-Type: application/sparql-query" \
    -H "Accept: application/sparql-results+json" \
    --data "
${PREFIX}
SELECT ?task WHERE {
  GRAPH <${RUNTIME_GRAPH}> {
    ?task a agentflow:TaskInstance .
    ?task agentflow:taskStatus \"COMPLETED\" .
  }
}" 2>/dev/null | jq -r '.results.bindings | length' 2>/dev/null)

if [[ "$TASK_COUNT" -ge 3 ]]; then
    printf '  ✅ E-03: Demo 1 has >= 3 completed tasks (got: %s)\n' "$TASK_COUNT"
    PASS=$((PASS + 1))
else
    printf '  ❌ E-03: Demo 1 expected >= 3 completed tasks (got: %s)\n' "$TASK_COUNT"
    FAIL=$((FAIL + 1))
fi

# ─── Demo 2: Git Push Safety ────────────────────────────
echo ''
echo '── Demo 2: Git Push Safety ──────────────────────────'

# Clean and load
curl -s -X DELETE "${FUSEKI_HOST}/\$/datasets/${DATASET}" > /dev/null 2>&1 || true
bash "${PROJECT_DIR}/scripts/load_ontology.sh" git-push-safety > /dev/null 2>&1

# Run engine in background (will block at approval gateway)
export APPROVAL_TIMEOUT_SECONDS=90
export APPROVAL_POLL_INTERVAL=3

echo '  [+] Running engine (background)...'
bash "${PROJECT_DIR}/engine/orchestrate.sh" --demo "${PROJECT_DIR}/demo/git-push-safety" > /tmp/agentflow_test_demo2.log 2>&1 &
ENGINE_PID=$!

# Wait for engine to reach the approval gateway
echo '  [+] Waiting for approval gateway...'
sleep 40

# Inject approval
echo '  [+] Injecting APPROVED...'
curl -s -o /dev/null -X POST "${UPDATE_URL}" \
    -H "Content-Type: application/sparql-update" \
    --data "PREFIX agentflow: <http://example.org/ontology/agentflow#>
    PREFIX ex: <http://example.org/instances/>
    INSERT DATA {
      GRAPH <${RUNTIME_GRAPH}> {
        _:approval a agentflow:ProcessVariable ;
          agentflow:varName \"approval_status\" ;
          agentflow:varValue \"APPROVED\" .
        ex:ProcInst_GitPush_001 agentflow:hasVariable _:approval .
      }
    }"

# Wait for engine to finish
wait $ENGINE_PID 2>/dev/null
ENGINE_EXIT=$?

if [[ $ENGINE_EXIT -eq 0 ]]; then
    printf '  ✅ E-04: Engine exits cleanly with approval (exit code 0)\n'
    PASS=$((PASS + 1))
else
    printf '  ❌ E-04: Engine failed (exit code %s)\n' "$ENGINE_EXIT"
    FAIL=$((FAIL + 1))
    echo '  --- Engine output (last 20 lines) ---'
    tail -20 /tmp/agentflow_test_demo2.log | sed 's/^/  /'
    echo '  ---'
fi

# Check process completed
STATUS=$(sparql_value "
${PREFIX}
SELECT ?status WHERE {
  GRAPH <${RUNTIME_GRAPH}> {
    ?proc a agentflow:ProcessInstance .
    ?proc agentflow:processStatus ?status .
  }
}")
assert_eq 'E-05' 'Demo 2 process status is COMPLETED' 'COMPLETED' "$STATUS"

# Check override was logged
OVERRIDE=$(sparql_value "
${PREFIX}
SELECT ?val WHERE {
  GRAPH <${RUNTIME_GRAPH}> {
    ?proc agentflow:hasVariable ?var .
    ?var agentflow:varName \"override_recorded\" .
    ?var agentflow:varValue ?val .
  }
}")
assert_eq 'E-06' 'Demo 2 override was recorded' 'true' "$OVERRIDE"

# Cleanup temp files
rm -f /tmp/agentflow_test_demo1.log /tmp/agentflow_test_demo2.log

# Cleanup Goose recipe sessions created during this test run
if [[ -f "$GOOSE_DB" ]] && command -v sqlite3 &>/dev/null; then
    CLEANED=$(sqlite3 "$GOOSE_DB" "
        DELETE FROM messages WHERE session_id IN (
            SELECT id FROM sessions
            WHERE recipe_json IS NOT NULL AND created_at >= '$TEST_START'
        );
        DELETE FROM usage_ledger WHERE session_id IN (
            SELECT id FROM sessions
            WHERE recipe_json IS NOT NULL AND created_at >= '$TEST_START'
        );
        DELETE FROM sessions
        WHERE recipe_json IS NOT NULL AND created_at >= '$TEST_START';
        SELECT changes();")
    [[ "$CLEANED" -gt 0 ]] 2>/dev/null && echo "  [+] Cleaned $CLEANED ephemeral Goose recipe sessions"
fi

echo ''
echo '══════════════════════════════════════════════════════'
if [[ $FAIL -eq 0 ]]; then
    echo "  Engine: $PASS passed, 0 failed ✅"
else
    echo "  Engine: $PASS passed, $FAIL FAILED ❌"
fi
echo '══════════════════════════════════════════════════════'

[[ $FAIL -eq 0 ]] || exit 1
