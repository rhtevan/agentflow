#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════
# AgentFLOW Orchestration Engine
#
# A deterministic, graph-driven process engine that moves
# tokens through an sBPMN process graph stored in Apache Jena.
#
# Usage: bash orchestrate.sh [--demo DEMO_DIR]
# ══════════════════════════════════════════════════════════
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Load config
if [[ -f "${SCRIPT_DIR}/config.env" ]]; then
    source "${SCRIPT_DIR}/config.env"
else
    source "${SCRIPT_DIR}/config.env.example"
fi

# CLI args
DEMO_DIR=""
PAUSE_MODE=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        --demo)   DEMO_DIR="$2"; shift 2 ;;
        --pause)  PAUSE_MODE=true; shift ;;
        *)        echo "Unknown arg: $1" >&2; exit 2 ;;
    esac
done

# ══════════════════════════════════════════════════════════
# HELPER FUNCTIONS
# ══════════════════════════════════════════════════════════

log_info()  { echo "  [+] $*"; }
log_ok()    { echo "  [✓] $*"; }
log_err()   { echo "  [✗] $*" >&2; }
log_event() { echo ""; echo "  [$1] $2"; }

sparql_query() {
    local query="$1"
    curl -s -X POST "${QUERY_URL}" \
        -H "Content-Type: application/sparql-query" \
        -H "Accept: application/sparql-results+json" \
        --data "$query"
}

sparql_update() {
    local update="$1"
    local http_code
    http_code=$(curl -s -o /dev/null -w '%{http_code}' \
        -X POST "${UPDATE_URL}" \
        -H "Content-Type: application/sparql-update" \
        --data "$update")
    if [[ "$http_code" != "200" && "$http_code" != "204" ]]; then
        log_err "SPARQL UPDATE failed (HTTP ${http_code})"
        return 1
    fi
}

pause_for_inspection() {
    if $PAUSE_MODE; then
        echo ""
        echo "  ┌─────────────────────────────────────────────────────┐"
        echo "  │  ⏸  PAUSED for inspection                          │"
        echo "  │  Fuseki UI: ${FUSEKI_HOST}/#/dataset/${DATASET}/query│"
        echo "  │  Press ENTER to continue...                         │"
        echo "  └─────────────────────────────────────────────────────┘"
        read -r
    fi
}

# ══════════════════════════════════════════════════════════
# FETCH CURRENT STATE
# ══════════════════════════════════════════════════════════

fetch_current_node() {
    sparql_query "
        PREFIX sbpmn:     <https://sBPMN.github.io/2.0/properties#>
        PREFIX agentflow: <http://example.org/ontology/agentflow#>
        PREFIX sbpmnc:    <https://sBPMN.github.io/2.0/classes#>
        PREFIX agentflow: <http://example.org/ontology/agentflow#>
        PREFIX rdfs:      <http://www.w3.org/2000/01/rdf-schema#>

        SELECT ?process ?processStatus ?taskInst ?taskDef ?taskLabel ?taskStatus
               ?nodeType ?recipe ?requiresApproval
        WHERE {
            GRAPH <${RUNTIME_GRAPH}> {
                ?process a agentflow:ProcessInstance ;
                         agentflow:processStatus ?processStatus ;
                         agentflow:currentTask ?taskInst .
                ?taskInst agentflow:instantiatesTask ?taskDef ;
                          agentflow:taskStatus ?taskStatus .
            }
            GRAPH <${DEFINITIONS_GRAPH}> {
                ?taskDef a ?nodeType .
                OPTIONAL { ?taskDef rdfs:label ?taskLabel }
                OPTIONAL { ?taskDef agentflow:recipe ?recipe }
                OPTIONAL { ?taskDef agentflow:requiresApproval ?requiresApproval }
                FILTER (?nodeType != <http://www.w3.org/2002/07/owl#NamedIndividual>)
            }
        }
        LIMIT 1
    "
}

# ══════════════════════════════════════════════════════════
# ADVANCE TOKEN — move to next node
# ══════════════════════════════════════════════════════════

advance_token() {
    local process_uri="$1"
    local current_inst_uri="$2"
    local current_def_uri="$3"
    local next_def_uri="$4"
    local triggered_by="${5:-BashFlowEngine}"

    sparql_update "
        PREFIX sbpmn: <https://sBPMN.github.io/2.0/properties#>
        PREFIX agentflow: <http://example.org/ontology/agentflow#>
        PREFIX xsd:   <http://www.w3.org/2001/XMLSchema#>

        DELETE {
            GRAPH <${RUNTIME_GRAPH}> {
                <${process_uri}> agentflow:currentTask <${current_inst_uri}> .
                <${current_inst_uri}> agentflow:taskStatus ?oldStatus .
            }
        }
        INSERT {
            GRAPH <${RUNTIME_GRAPH}> {
                <${current_inst_uri}> agentflow:taskStatus \"COMPLETED\" .
                <${current_inst_uri}> agentflow:endTime ?now .

                ?newTaskInst a agentflow:TaskInstance ;
                    agentflow:instantiatesTask <${next_def_uri}> ;
                    agentflow:taskStatus \"RUNNING\" ;
                    agentflow:startTime ?now .

                <${process_uri}> agentflow:currentTask ?newTaskInst .

                <${current_inst_uri}> agentflow:followedBy ?newTaskInst .
            }
        }
        WHERE {
            GRAPH <${RUNTIME_GRAPH}> {
                <${current_inst_uri}> agentflow:taskStatus ?oldStatus .
            }
            BIND(NOW() AS ?now)
            BIND(IRI(CONCAT(\"http://example.org/instances/TaskInst_\", STRUUID())) AS ?newTaskInst)
        }
    "
}

# ══════════════════════════════════════════════════════════
# COMPLETE PROCESS — mark as finished at EndEvent
# ══════════════════════════════════════════════════════════

complete_process() {
    local process_uri="$1"
    local current_inst_uri="$2"
    local end_status="${3:-COMPLETED}"

    sparql_update "
        PREFIX sbpmn: <https://sBPMN.github.io/2.0/properties#>
        PREFIX agentflow: <http://example.org/ontology/agentflow#>

        DELETE {
            GRAPH <${RUNTIME_GRAPH}> {
                <${process_uri}> agentflow:currentTask <${current_inst_uri}> .
                <${process_uri}> agentflow:processStatus ?oldStatus .
                <${current_inst_uri}> agentflow:taskStatus ?oldTaskStatus .
            }
        }
        INSERT {
            GRAPH <${RUNTIME_GRAPH}> {
                <${process_uri}> agentflow:processStatus \"${end_status}\" .
                <${current_inst_uri}> agentflow:taskStatus \"COMPLETED\" .
                <${current_inst_uri}> agentflow:endTime ?now .
            }
        }
        WHERE {
            GRAPH <${RUNTIME_GRAPH}> {
                <${process_uri}> agentflow:processStatus ?oldStatus .
                <${current_inst_uri}> agentflow:taskStatus ?oldTaskStatus .
            }
            BIND(NOW() AS ?now)
        }
    "
}

# ══════════════════════════════════════════════════════════
# GET NEXT NODE — find the next node via agentflow:nextTask
# ══════════════════════════════════════════════════════════

get_next_node() {
    local current_def_uri="$1"
    sparql_query "
        PREFIX sbpmn: <https://sBPMN.github.io/2.0/properties#>
        PREFIX agentflow: <http://example.org/ontology/agentflow#>

        SELECT ?next WHERE {
            GRAPH <${DEFINITIONS_GRAPH}> {
                <${current_def_uri}> agentflow:nextTask ?next .
            }
        }
        LIMIT 1
    " | jq -r '.results.bindings[0].next.value // empty'
}

# ══════════════════════════════════════════════════════════
# EXECUTE AGENTIC TASK — invoke Goose recipe
# ══════════════════════════════════════════════════════════

execute_agentic_task() {
    local process_uri="$1"
    local task_inst_uri="$2"
    local task_def_uri="$3"
    local recipe_name="$4"

    # Find recipe file
    local recipe_file=""
    if [[ -n "$DEMO_DIR" && -f "${DEMO_DIR}/recipes/${recipe_name}.yaml" ]]; then
        recipe_file="${DEMO_DIR}/recipes/${recipe_name}.yaml"
    elif [[ -f "${PROJECT_DIR}/recipes/${recipe_name}.yaml" ]]; then
        recipe_file="${PROJECT_DIR}/recipes/${recipe_name}.yaml"
    else
        log_err "Recipe not found: ${recipe_name}.yaml"
        return 1
    fi

    # Extract process variables from ABox as params
    local params_json
    params_json=$(sparql_query "
        PREFIX sbpmn: <https://sBPMN.github.io/2.0/properties#>
        PREFIX agentflow: <http://example.org/ontology/agentflow#>

        SELECT ?varName ?varValue WHERE {
            GRAPH <${RUNTIME_GRAPH}> {
                <${process_uri}> agentflow:hasVariable ?var .
                ?var agentflow:varName ?varName ;
                     agentflow:varValue ?varValue .
            }
        }
    " | jq -r '[ .results.bindings[] | { (.varName.value): .varValue.value } ] | add // {}')

    local params_file
    params_file=$(mktemp /tmp/agentflow_params_XXXXXX.json)
    echo "$params_json" > "$params_file"

    log_info "Params: $(echo "$params_json" | jq -c .)"

    # Execute Goose recipe
    local output_file
    output_file=$(mktemp /tmp/agentflow_output_XXXXXX.json)

    log_info "Executing: ${GOOSE_CMD} run --recipe ${recipe_file}"

    # Build --params flags from the params JSON
    local params_flags=()
    while IFS= read -r key; do
        local val
        val=$(echo "$params_json" | jq -r ".\"${key}\"")
        params_flags+=(--params "${key}=${val}")
    done < <(echo "$params_json" | jq -r 'keys[]')

    if "${GOOSE_CMD}" run --recipe "$recipe_file" \
            "${params_flags[@]}" \
            --quiet > "$output_file" 2>/dev/null; then
        log_ok "Recipe execution succeeded"
    else
        log_err "Recipe execution failed"
        rm -f "$params_file" "$output_file"
        return 1
    fi

    # Validate JSON output — Goose may wrap JSON in markdown code fences
    if ! jq . "$output_file" > /dev/null 2>&1; then
        local extracted=""
        # Try 1: strip markdown code fences (```json ... ```)
        extracted=$(sed -n '/^```/,/^```/{ /^```/d; p }' "$output_file" | jq -r . 2>/dev/null && echo "_OK_" || true)
        if [[ "$extracted" == *"_OK_"* ]]; then
            sed -n '/^```/,/^```/{ /^```/d; p }' "$output_file" > "${output_file}.clean"
            mv "${output_file}.clean" "$output_file"
        else
            # Try 2: find first { to last } on a single line
            extracted=$(grep -o '{.*}' "$output_file" | head -1 || true)
            if [[ -n "$extracted" ]] && echo "$extracted" | jq . > /dev/null 2>&1; then
                echo "$extracted" > "$output_file"
            else
                # Try 3: extract multiline JSON block
                extracted=$(sed -n '/{/,/}/p' "$output_file" | jq -r . 2>/dev/null && echo "_OK_" || true)
                if [[ "$extracted" == *"_OK_"* ]]; then
                    sed -n '/{/,/}/p' "$output_file" > "${output_file}.clean"
                    mv "${output_file}.clean" "$output_file"
                else
                    log_err "Invalid JSON output from recipe"
                    cat "$output_file" >&2
                    rm -f "$params_file" "$output_file"
                    return 1
                fi
            fi
        fi
    fi

    local task_output
    task_output=$(cat "$output_file")
    log_info "Output: $(echo "$task_output" | jq -c .)"

    # Store output on TaskInstance
    local escaped_output
    escaped_output=$(echo "$task_output" | jq -Rs .)
    sparql_update "
        PREFIX sbpmn: <https://sBPMN.github.io/2.0/properties#>
        PREFIX agentflow: <http://example.org/ontology/agentflow#>

        INSERT {
            GRAPH <${RUNTIME_GRAPH}> {
                <${task_inst_uri}> agentflow:taskOutput ${escaped_output} .
            }
        }
        WHERE {}
    "

    # Write output keys as process variables
    # Stringify all values (arrays/objects become JSON strings, scalars stay as-is)
    local var_updates=""
    while IFS= read -r key; do
        local val
        val=$(echo "$task_output" | jq -r "if .\"${key}\" | type == \"array\" or type == \"object\" then (.\"${key}\" | tostring) else (.\"${key}\" | tostring) end")
        # Escape quotes and backslashes for SPARQL literal
        val=$(echo "$val" | sed 's/\\/\\\\/g; s/"/\\"/g')
        var_updates+="
            _:var_${key} a agentflow:ProcessVariable ;
                agentflow:varName \"${key}\" ;
                agentflow:varValue \"${val}\" .
            <${process_uri}> agentflow:hasVariable _:var_${key} .
        "
    done < <(echo "$task_output" | jq -r 'keys[]')

    if [[ -n "$var_updates" ]]; then
        sparql_update "
            PREFIX agentflow: <http://example.org/ontology/agentflow#>

            INSERT DATA {
                GRAPH <${RUNTIME_GRAPH}> {
                    ${var_updates}
                }
            }
        "
        log_ok "Output merged to ABox"
    fi

    rm -f "$params_file" "$output_file"
}

# ══════════════════════════════════════════════════════════
# EVALUATE GATEWAY — conditional routing via SPARQL
# ══════════════════════════════════════════════════════════

evaluate_gateway() {
    local process_uri="$1"
    local task_inst_uri="$2"
    local task_def_uri="$3"
    local requires_approval="${4:-false}"

    # If approval required, poll for the variable
    if [[ "$requires_approval" == "true" ]]; then
        poll_for_approval "$process_uri" "$task_def_uri"
    fi

    # Get all outgoing edges with conditions
    local edges
    edges=$(sparql_query "
        PREFIX sbpmn: <https://sBPMN.github.io/2.0/properties#>
        PREFIX agentflow: <http://example.org/ontology/agentflow#>

        SELECT ?target ?varName ?operator ?threshold ?isDefault WHERE {
            GRAPH <${DEFINITIONS_GRAPH}> {
                <${task_def_uri}> agentflow:nextTask ?target .
                OPTIONAL {
                    << <${task_def_uri}> agentflow:nextTask ?target >>
                        agentflow:varName ?varName ;
                        agentflow:operator ?operator ;
                        agentflow:threshold ?threshold .
                }
                OPTIONAL {
                    << <${task_def_uri}> agentflow:nextTask ?target >>
                        agentflow:isDefault ?isDefault .
                }
            }
        }
    ")

    local selected_target=""
    local default_target=""
    local eval_var_name=""
    local eval_var_value=""

    # Iterate through edges
    local edge_count
    edge_count=$(echo "$edges" | jq '.results.bindings | length')

    for ((i=0; i<edge_count; i++)); do
        local target var_name operator threshold is_default
        target=$(echo "$edges" | jq -r ".results.bindings[$i].target.value // empty")
        var_name=$(echo "$edges" | jq -r ".results.bindings[$i].varName.value // empty")
        operator=$(echo "$edges" | jq -r ".results.bindings[$i].operator.value // empty")
        threshold=$(echo "$edges" | jq -r ".results.bindings[$i].threshold.value // empty")
        is_default=$(echo "$edges" | jq -r ".results.bindings[$i].isDefault.value // empty")

        if [[ "$is_default" == "true" ]]; then
            default_target="$target"
        fi

        if [[ -n "$var_name" && -n "$operator" ]]; then
            # Get variable value from ABox
            local var_value
            var_value=$(sparql_query "
                PREFIX sbpmn: <https://sBPMN.github.io/2.0/properties#>
                PREFIX agentflow: <http://example.org/ontology/agentflow#>

                SELECT ?varValue WHERE {
                    GRAPH <${RUNTIME_GRAPH}> {
                        <${process_uri}> agentflow:hasVariable ?var .
                        ?var agentflow:varName \"${var_name}\" ;
                             agentflow:varValue ?varValue .
                    }
                }
                ORDER BY DESC(?varValue)
                LIMIT 1
            " | jq -r '.results.bindings[0].varValue.value // empty')

            log_info "Evaluating: ${var_name} ${operator} ${threshold} (actual: ${var_value})"

            local match=false
            case "$operator" in
                "==") [[ "$var_value" == "$threshold" ]] && match=true ;;
                ">")  [[ $(echo "$var_value > $threshold" | bc -l 2>/dev/null || echo 0) -eq 1 ]] && match=true ;;
                ">=") [[ $(echo "$var_value >= $threshold" | bc -l 2>/dev/null || echo 0) -eq 1 ]] && match=true ;;
                "<")  [[ $(echo "$var_value < $threshold" | bc -l 2>/dev/null || echo 0) -eq 1 ]] && match=true ;;
                "<=") [[ $(echo "$var_value <= $threshold" | bc -l 2>/dev/null || echo 0) -eq 1 ]] && match=true ;;
            esac

            if $match; then
                log_ok "Condition matched → routing to: $(basename "$target")"
                selected_target="$target"
                eval_var_name="$var_name"
                eval_var_value="$var_value"
                break
            else
                log_info "Condition not matched"
            fi
        fi
    done

    local final_target="${selected_target:-$default_target}"

    if [[ -z "$final_target" ]]; then
        log_err "Gateway deadlock — no route matched and no default defined"
        return 1
    fi

    if [[ -z "$selected_target" ]]; then
        log_ok "Default route taken → $(basename "$final_target")"
    fi

    # Advance token to selected target
    advance_token "$process_uri" "$task_inst_uri" "$task_def_uri" "$final_target"
}

# ══════════════════════════════════════════════════════════
# POLL FOR APPROVAL — human-in-the-loop
# ══════════════════════════════════════════════════════════

poll_for_approval() {
    local process_uri="$1"
    local gateway_def_uri="$2"

    # Find the variable name this gateway checks
    local var_name
    var_name=$(sparql_query "
        PREFIX sbpmn: <https://sBPMN.github.io/2.0/properties#>
        PREFIX agentflow: <http://example.org/ontology/agentflow#>

        SELECT ?varName WHERE {
            GRAPH <${DEFINITIONS_GRAPH}> {
                << <${gateway_def_uri}> agentflow:nextTask ?anyTarget >>
                    agentflow:varName ?varName .
            }
        }
        LIMIT 1
    " | jq -r '.results.bindings[0].varName.value // empty')

    if [[ -z "$var_name" ]]; then
        var_name="approval_status"
    fi

    echo ""
    echo "  ┌─────────────────────────────────────────────────────┐"
    echo "  │  ⚠️  APPROVAL REQUIRED                              │"
    echo "  │                                                     │"
    echo "  │  To approve:                                        │"
    echo "  │  make approve PROCESS=$(basename "$process_uri")     │"
    echo "  │               VALUE=APPROVED                        │"
    echo "  │                                                     │"
    echo "  │  To deny:                                           │"
    echo "  │  make approve PROCESS=$(basename "$process_uri")     │"
    echo "  │               VALUE=DENIED                          │"
    echo "  │                                                     │"
    echo "  │  Timeout: ${APPROVAL_TIMEOUT_SECONDS}s (auto-DENIED)│"
    echo "  └─────────────────────────────────────────────────────┘"
    echo ""

    local elapsed=0
    while [[ $elapsed -lt $APPROVAL_TIMEOUT_SECONDS ]]; do
        local value
        value=$(sparql_query "
            PREFIX sbpmn: <https://sBPMN.github.io/2.0/properties#>
                PREFIX agentflow: <http://example.org/ontology/agentflow#>

            SELECT ?varValue WHERE {
                GRAPH <${RUNTIME_GRAPH}> {
                    <${process_uri}> agentflow:hasVariable ?var .
                    ?var agentflow:varName \"${var_name}\" ;
                         agentflow:varValue ?varValue .
                }
            }
            ORDER BY DESC(?varValue)
            LIMIT 1
        " | jq -r '.results.bindings[0].varValue.value // empty')

        if [[ -n "$value" ]]; then
            log_ok "Approval variable '${var_name}' = '${value}'"
            return 0
        fi

        echo -n "."
        sleep "$APPROVAL_POLL_INTERVAL"
        elapsed=$((elapsed + APPROVAL_POLL_INTERVAL))
    done

    echo ""
    log_err "Approval timeout after ${APPROVAL_TIMEOUT_SECONDS}s — auto-DENIED"

    sparql_update "
        PREFIX sbpmn: <https://sBPMN.github.io/2.0/properties#>
        PREFIX agentflow: <http://example.org/ontology/agentflow#>

        INSERT DATA {
            GRAPH <${RUNTIME_GRAPH}> {
                _:timeout_var a agentflow:ProcessVariable ;
                    agentflow:varName \"${var_name}\" ;
                    agentflow:varValue \"DENIED\" .
                <${process_uri}> agentflow:hasVariable _:timeout_var .
            }
        }
    "
}

# ══════════════════════════════════════════════════════════
# MAIN ENGINE LOOP
# ══════════════════════════════════════════════════════════

echo "══════════════════════════════════════════════════════"
echo "  AgentFLOW Orchestration Engine"
echo "══════════════════════════════════════════════════════"

while true; do
    # Fetch current node
    RESULT=$(fetch_current_node)

    PROCESS_URI=$(echo "$RESULT" | jq -r '.results.bindings[0].process.value // empty')
    PROCESS_STATUS=$(echo "$RESULT" | jq -r '.results.bindings[0].processStatus.value // empty')
    TASK_INST_URI=$(echo "$RESULT" | jq -r '.results.bindings[0].taskInst.value // empty')
    TASK_DEF_URI=$(echo "$RESULT" | jq -r '.results.bindings[0].taskDef.value // empty')
    TASK_LABEL=$(echo "$RESULT" | jq -r '.results.bindings[0].taskLabel.value // empty')
    TASK_STATUS=$(echo "$RESULT" | jq -r '.results.bindings[0].taskStatus.value // empty')
    NODE_TYPE=$(echo "$RESULT" | jq -r '.results.bindings[0].nodeType.value // empty')
    RECIPE=$(echo "$RESULT" | jq -r '.results.bindings[0].recipe.value // empty')
    REQUIRES_APPROVAL=$(echo "$RESULT" | jq -r '.results.bindings[0].requiresApproval.value // empty')

    # No active token — done
    if [[ -z "$PROCESS_URI" ]]; then
        echo ""
        log_info "No active process instance found. Done."
        break
    fi

    # ── StartEvent ────────────────────────────────────
    if [[ "$NODE_TYPE" == *"startEvent"* ]]; then
        log_event "→" "startEvent: ${TASK_LABEL:-start}"
        NEXT=$(get_next_node "$TASK_DEF_URI")
        if [[ -z "$NEXT" ]]; then
            log_err "StartEvent has no outgoing edge"
            exit 1
        fi
        advance_token "$PROCESS_URI" "$TASK_INST_URI" "$TASK_DEF_URI" "$NEXT"
        log_ok "Advancing token"
        pause_for_inspection
        continue
    fi

    # ── EndEvent ──────────────────────────────────────
    if [[ "$NODE_TYPE" == *"endEvent"* ]]; then
        log_event "⏹" "endEvent: ${TASK_LABEL:-end}"
        complete_process "$PROCESS_URI" "$TASK_INST_URI"
        log_ok "Process COMPLETED"
        break
    fi

    # ── AgenticTask ───────────────────────────────────
    if [[ "$NODE_TYPE" == *"AgenticTask"* ]]; then
        log_event "■" "AgenticTask: ${TASK_LABEL}"
        log_info "Recipe: ${RECIPE}.yaml"

        if ! execute_agentic_task "$PROCESS_URI" "$TASK_INST_URI" "$TASK_DEF_URI" "$RECIPE"; then
            log_err "Task execution failed — halting engine"
            exit 1
        fi

        NEXT=$(get_next_node "$TASK_DEF_URI")
        if [[ -z "$NEXT" ]]; then
            log_err "AgenticTask has no outgoing edge"
            exit 1
        fi
        advance_token "$PROCESS_URI" "$TASK_INST_URI" "$TASK_DEF_URI" "$NEXT"
        pause_for_inspection
        continue
    fi

    # ── Gateway (ExclusiveGateway or GuardrailGateway) ─
    if [[ "$NODE_TYPE" == *"ateway"* ]]; then
        gw_type="ExclusiveGateway"
        [[ "$NODE_TYPE" == *"GuardrailGateway"* ]] && gw_type="GuardrailGateway"
        log_event "◆" "${gw_type}: ${TASK_LABEL}"

        if ! evaluate_gateway "$PROCESS_URI" "$TASK_INST_URI" "$TASK_DEF_URI" "${REQUIRES_APPROVAL:-false}"; then
            log_err "Gateway evaluation failed — halting engine"
            exit 1
        fi

        pause_for_inspection
        continue
    fi

    # ── Unknown node type ─────────────────────────────
    log_err "Unknown node type: ${NODE_TYPE}"
    exit 1
done

echo ""
echo "══════════════════════════════════════════════════════"
echo "  Engine Stopped"
echo "══════════════════════════════════════════════════════"
