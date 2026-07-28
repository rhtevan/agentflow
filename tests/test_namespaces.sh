#!/usr/bin/env bash
# test_namespaces.sh — Verify namespace consistency across all project files
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

PASS=0
FAIL=0

check_absent() {
    local pattern="$1" label="$2"
    local matches
    matches=$(grep -r --include='*.ttl' --include='*.rq' --include='*.sh' --include='*.yaml' \
        "$pattern" "$PROJECT_DIR" \
        --exclude-dir=.git --exclude-dir=.agents --exclude-dir=tests \
        2>/dev/null || true)
    if [[ -z "$matches" ]]; then
        printf '  ✅ No stale references: %s\n' "$label"
        PASS=$((PASS + 1))
    else
        printf '  ❌ Found stale references: %s\n' "$label"
        echo "$matches" | head -10 | sed 's/^/     /'
        FAIL=$((FAIL + 1))
    fi
}

check_present() {
    local pattern="$1" label="$2" filetype="$3"
    local matches
    matches=$(grep -rl --include="$filetype" \
        "$pattern" "$PROJECT_DIR" \
        --exclude-dir=.git --exclude-dir=.agents --exclude-dir=tests \
        2>/dev/null || true)
    if [[ -n "$matches" ]]; then
        local count
        count=$(echo "$matches" | wc -l)
        printf '  ✅ Found %s in %d files: %s\n' "$label" "$count" "$(echo "$matches" | sed "s|$PROJECT_DIR/||g" | tr '\n' ' ')"
        PASS=$((PASS + 1))
    else
        printf '  ❌ Not found anywhere: %s\n' "$label"
        FAIL=$((FAIL + 1))
    fi
}

echo '══════════════════════════════════════════════════════'
echo '  Test: Namespace Consistency'
echo '══════════════════════════════════════════════════════'
echo ''

echo '── Stale Namespace Checks ───────────────────────────'
check_absent 'example.org/ontology/sbpmn'  'old sbpmn namespace'
check_absent 'example.org/ontology/sbpmnc' 'old sbpmnc namespace'
check_absent 'example.org/ontology/cto'    'old cto namespace'

echo ''
echo '── Correct Namespace Checks ─────────────────────────'
check_present 'sBPMN.github.io/2.0/classes'    'sBPMN classes namespace'    '*.ttl'
check_present 'sBPMN.github.io/2.0/properties' 'sBPMN properties namespace' '*.ttl'
check_present 'Point-Topic/cto-ontology'       'CTO namespace'             '*.ttl'
check_present 'example.org/ontology/agentflow'  'AgentFLOW namespace'       '*.ttl'

echo ''
echo '══════════════════════════════════════════════════════'
if [[ $FAIL -eq 0 ]]; then
    echo "  Namespaces: $PASS passed, 0 failed ✅"
else
    echo "  Namespaces: $PASS passed, $FAIL FAILED ❌"
fi
echo '══════════════════════════════════════════════════════'

[[ $FAIL -eq 0 ]] || exit 1
