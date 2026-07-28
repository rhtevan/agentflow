#!/usr/bin/env bash
# test_syntax.sh — Validate all Turtle files parse correctly
set -euo pipefail

export PATH="$HOME/.local/share/apache-jena/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

PASS=0
FAIL=0

check_syntax() {
    local file="$1"
    local relpath="${file#$PROJECT_DIR/}"
    if riot --validate "$file" > /dev/null 2>&1; then
        printf '  ✅ %s\n' "$relpath"
        PASS=$((PASS + 1))
    else
        printf '  ❌ %s\n' "$relpath"
        riot --validate "$file" 2>&1 | head -5
        FAIL=$((FAIL + 1))
    fi
}

echo '══════════════════════════════════════════════════════'
echo '  Test: Turtle Syntax Validation'
echo '══════════════════════════════════════════════════════'
echo ''

echo '── Ontology ──────────────────────────────────────────'
for f in "$PROJECT_DIR"/ontology/*.ttl; do
    [ -f "$f" ] && check_syntax "$f"
done

echo ''
echo '── SHACL Shapes ────────────────────────────────────'
for f in "$PROJECT_DIR"/ontology/shapes/*.ttl; do
    [ -f "$f" ] && check_syntax "$f"
done

echo ''
echo '── Demo Definitions & Runtime ───────────────────────'
for f in "$PROJECT_DIR"/demo/*/definitions.ttl "$PROJECT_DIR"/demo/*/runtime.ttl; do
    [ -f "$f" ] && check_syntax "$f"
done

echo ''
echo '══════════════════════════════════════════════════════'
if [[ $FAIL -eq 0 ]]; then
    echo "  Syntax: $PASS passed, 0 failed ✅"
else
    echo "  Syntax: $PASS passed, $FAIL FAILED ❌"
fi
echo '══════════════════════════════════════════════════════'

[[ $FAIL -eq 0 ]] || exit 1
