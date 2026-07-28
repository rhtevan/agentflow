#!/usr/bin/env bash
# cleanup.sh — Stop Fuseki and remove temporary files
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

if [[ -f "${PROJECT_DIR}/engine/config.env" ]]; then
    source "${PROJECT_DIR}/engine/config.env"
else
    source "${PROJECT_DIR}/engine/config.env.example"
fi

echo '══════════════════════════════════════════════════════'
echo '  AgentFLOW Cleanup'
echo '══════════════════════════════════════════════════════'

# Drop dataset
echo '  [+] Removing dataset...'
curl -s -X DELETE "${FUSEKI_HOST}/\$/datasets/${DATASET}" > /dev/null 2>&1 || true
echo '  [✓] Dataset removed'

# Clean temp files
echo '  [+] Cleaning temp files...'
rm -f /tmp/agentflow_params_*.json /tmp/agentflow_output_*.json /tmp/agentflow_demo*.log
echo '  [✓] Temp files cleaned'

echo ''
echo '══════════════════════════════════════════════════════'
echo '  Cleanup Complete'
echo '══════════════════════════════════════════════════════'
