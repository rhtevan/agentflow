#!/usr/bin/env bash
# run_all.sh — Master test runner for AgentFLOW
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

TOTAL_PASS=0
TOTAL_FAIL=0
SUITES_PASS=0
SUITES_FAIL=0

run_suite() {
    local name="$1" script="$2" requires_fuseki="${3:-false}"
    
    if [[ "$requires_fuseki" == "true" ]]; then
        local http_code
        http_code=$(curl -s -o /dev/null -w '%{http_code}' 'http://localhost:3030/$/ping' 2>/dev/null || echo '000')
        if [[ "$http_code" != "200" ]]; then
            echo ''
            echo "⏭  Skipping: $name (Fuseki not running)"
            return 0
        fi
    fi
    
    echo ''
    if bash "$script"; then
        SUITES_PASS=$((SUITES_PASS + 1))
    else
        SUITES_FAIL=$((SUITES_FAIL + 1))
    fi
}

MODE="${1:-all}"

echo '██████████████████████████████████████████████████████'
echo '  AgentFLOW Test Suite'
echo '██████████████████████████████████████████████████████'

case "$MODE" in
    fast)
        echo '  Mode: fast (no Fuseki/Goose required)'
        run_suite 'Turtle Syntax'         "${SCRIPT_DIR}/test_syntax.sh"
        run_suite 'Namespace Consistency' "${SCRIPT_DIR}/test_namespaces.sh"
        ;;
    all)
        echo '  Mode: all'
        run_suite 'Turtle Syntax'         "${SCRIPT_DIR}/test_syntax.sh"
        run_suite 'Namespace Consistency' "${SCRIPT_DIR}/test_namespaces.sh"
        run_suite 'Ontology Structure'    "${SCRIPT_DIR}/test_structure.sh"   true
        run_suite 'Engine End-to-End'     "${SCRIPT_DIR}/test_engine.sh"      true
        ;;
    syntax)
        run_suite 'Turtle Syntax'         "${SCRIPT_DIR}/test_syntax.sh"
        ;;
    namespaces)
        run_suite 'Namespace Consistency' "${SCRIPT_DIR}/test_namespaces.sh"
        ;;
    structure)
        run_suite 'Ontology Structure'    "${SCRIPT_DIR}/test_structure.sh"   true
        ;;
    engine)
        run_suite 'Engine End-to-End'     "${SCRIPT_DIR}/test_engine.sh"      true
        ;;
    *)
        echo "Usage: $0 [fast|all|syntax|namespaces|structure|engine]"
        exit 1
        ;;
esac

echo ''
echo '██████████████████████████████████████████████████████'
if [[ $SUITES_FAIL -eq 0 ]]; then
    echo "  All $SUITES_PASS test suites PASSED ✅"
else
    echo "  $SUITES_PASS suites passed, $SUITES_FAIL FAILED ❌"
fi
echo '██████████████████████████████████████████████████████'

[[ $SUITES_FAIL -eq 0 ]] || exit 1
