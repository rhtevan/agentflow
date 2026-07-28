# AgentFLOW Architecture

## Overview

AgentFLOW is a graph-driven agent orchestrator that replaces instruction-based
orchestration with topology-based orchestration. The system has four layers:

1. **Graph Store** (Apache Jena Fuseki) — process topology and runtime state
2. **Orchestration Engine** (Bash) — stateless loop that moves tokens
3. **Task Executor** (Goose CLI) — fresh-context LLM execution per task
4. **Validation** (SHACL) — pre-flight structural integrity checks

## Data Layer: TBox / ABox Separation

The system uses two named graphs in a single Fuseki dataset:

| Named Graph | Content | Mutability |
|-------------|---------|------------|
| `http://example.org/graphs/definitions` | Process blueprints, task definitions, gateway conditions, CTO schema, ontology classes | **Read-only** at runtime |
| `http://example.org/graphs/runtime` | Process instances, task instances, variables, transition audit trail | **Read/write** via SPARQL UPDATE |

This separation guarantees the engine can never accidentally corrupt
process definitions during execution.

## Engine Loop

The orchestration engine (`engine/orchestrate.sh`) runs a single-threaded
poll loop:

```
while active_node exists:
    SPARQL SELECT → fetch current node from ABox

    if StartEvent:
        advance token to next node

    if EndEvent:
        mark process COMPLETED, exit

    if AgenticTask:
        SHACL validate (pre-flight)
        SPARQL SELECT → extract params from ABox
        build ephemeral params.json
        goose run --recipe <name>.yaml --params ... --quiet
        validate JSON output
        SPARQL UPDATE → write output to ABox as process variables
        advance token to next node

    if Gateway:
        if requiresApproval == true:
            poll ABox for approval variable (human-in-the-loop)
        SPARQL SELECT → get outgoing edges with conditions
        evaluate conditions against ABox variables
        if no match: take default route
        if no route: halt with error
        advance token to matched target
```

## State Management (Approach C)

- **ABox is canonical** — all process state lives as RDF triples
- **`params.json` is ephemeral** — built from SPARQL results per task,
  passed to Goose, then discarded
- **Output flows back to ABox** — Goose JSON output is parsed and
  written as `ProcessVariable` triples via SPARQL UPDATE

## The Object Under Process

The process graph operates *on* a domain object that exists
independently of the process:

| Demo | Object | Representation |
|------|--------|----------------|
| SIM Activation | SIM card + HLR node | CTO entities in TBox + variables in ABox |
| Git Push Safety | Git working directory | Filesystem, referenced by ABox variables |

## Class Hierarchy

### AgenticTask

A new task type that BPMN didn't anticipate:
- Like **UserTask**: requires an actor, engine waits, actor exercises judgment
- Like **ScriptTask**: automated invocation, structured I/O, fast completion
- Unlike both: **stateless actor**, non-deterministic output, recipe-driven

```
sbpmnc:Task
└── agentflow:AgenticTask    ← LLM actor, stateless, recipe-driven
```

### GuardrailGateway

A complex gateway that supports two modes:
- **Self-evaluation** (`requiresApproval = false`): behaves like ExclusiveGateway
- **Human-in-the-loop** (`requiresApproval = true`): polls for external approval

```
sbpmnc:ComplexGateway
└── agentflow:GuardrailGateway    ← wait-optional + evaluate + enforce
```

The engine difference between ExclusiveGateway and GuardrailGateway
is one `if` statement:

```bash
if [[ "$requires_approval" == "true" ]]; then
    poll_for_approval
fi
# Then evaluate conditions (same SPARQL for both types)
```

## Turtle-star (RDF 1.2)

Gateway conditions and transition audit metadata are attached to
edges using Turtle-star inline annotations:

```turtle
# Gateway condition on sequence flow edge
ex:GW_SeverityCheck sbpmn:nextTask ex:Task_Escalate {|
    sbpmn:varName   "severity" ;
    sbpmn:operator  "==" ;
    sbpmn:threshold "CRITICAL" ;
    sbpmn:isDefault false
|} .
```

This avoids RDF reification while providing property-graph ergonomics.

## Goose Coupling

The engine is coupled to Goose CLI in two places:

1. `agentflow:recipe` property in the ontology (one property)
2. `execute_agentic_task()` function in `orchestrate.sh` (one function)

Swapping to another agent requires rewriting one function and converting
recipe YAML files. Everything else — graph topology, SPARQL queries,
SHACL validation, gateway routing — stays identical.
