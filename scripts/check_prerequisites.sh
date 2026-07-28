#!/usr/bin/env bash
# check_prerequisites.sh — Verify AgentFLOW dependencies
set -euo pipefail

export PATH="$HOME/.local/share/apache-jena/bin:$HOME/.local/share/apache-jena-fuseki:$PATH"

PASS=0
FAIL=0

check() {
    local name="$1" cmd="$2" ver_cmd="$3" min_ver="${4:-}"
    if command -v "$cmd" &>/dev/null; then
        local ver
        ver=$(eval "$ver_cmd" 2>&1 | head -1)
        printf '  ✅ %-20s %s\n' "$name" "$ver"
        PASS=$((PASS + 1))
    else
        printf '  ❌ %-20s NOT FOUND\n' "$name"
        FAIL=$((FAIL + 1))
    fi
}

echo '══════════════════════════════════════════════════════'
echo '  AgentFLOW Prerequisites Check'
echo '══════════════════════════════════════════════════════'
echo ''

check 'Java 17+'          java          'java -version 2>&1 | head -1'
check 'Jena riot'         riot          'riot --version'
check 'Jena shacl'        shacl         'shacl --version'
check 'Jena Fuseki'       fuseki-server 'fuseki-server --version 2>&1 | grep version'
check 'jq'                jq            'jq --version'
check 'curl'              curl          'curl --version | head -1'
check 'Goose CLI'         goose         'goose --version'
check 'bash'              bash          'bash --version | head -1'

echo ''
echo '══════════════════════════════════════════════════════'
if [[ $FAIL -eq 0 ]]; then
    echo "  All $PASS prerequisites satisfied ✅"
else
    echo "  $PASS passed, $FAIL missing ❌"
fi
echo '══════════════════════════════════════════════════════'

[[ $FAIL -eq 0 ]] || exit 1
