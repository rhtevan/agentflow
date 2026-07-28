# AgentFLOW (agent-flow)

Graph-driven agent orchestrator using sBPMN, OWL, and Apache Jena
to enforce deterministic multi-step LLM workflows.

Part of the **agent-x trilogy**:
- **AgentFS** (agent-filesystem) — foundation file structures for agents
- **AgentFLOW** (agent-flow) — deterministic workflow orchestration ← this project
- **AgentBOX** (agent-box) — secure enterprise sandbox for agent sessions

## The Problem

Modern agentic AI relies on a monolithic autonomy model where a single LLM
observes, plans, decides, and acts within a single conversation context.
Instructions and guardrails are delivered as natural language — guidance that
the model may follow, forget, reinterpret, or override.

This has three structural weaknesses:

1. **Stochastic behavior** — same prompt, different plans, different outputs
2. **Context degradation** — instruction adherence declines as context grows
3. **No structural enforcement** — guardrails are suggestions, not law

## The Insight

Manufacturing solved quality and consistency not by hiring smarter workers,
but by designing a better pipeline. AgentFLOW applies the same principle:

> **Instructions are suggestions. Graph edges are law.**

Each task is simple enough that any competent LLM can execute it reliably in
a fresh context. Consistency comes from the **graph topology** — the edges,
the gateways, the validation gates — not from the model being smart enough
to follow a complex instruction prompt.

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                APACHE JENA FUSEKI                   │
│  ┌───────────────────┐   ┌────────────────────────┐ │
│  │ TBox (definitions)│   │ ABox (runtime state)   │ │
│  │ READ-ONLY         │   │ READ/WRITE via SPARQL  │ │
│  └───────────────────┘   └────────────────────────┘ │
└─────────────────┬──────────────────┬────────────────┘
                  │ SPARQL SELECT    │ SPARQL UPDATE
                  ▼                  ▲
┌─────────────────────────────────────────────────────┐
│             ORCHESTRATION ENGINE (Bash)             │
│    poll → validate (SHACL) → execute → advance      │
└─────────────────┬───────────────────────────────────┘
                  │ goose run --recipe
                  ▼
┌─────────────────────────────────────────────────────┐
│              GOOSE CLI (Task Executor)              │
│   Fresh context per task (Ralph Loop pattern)       │
└─────────────────────────────────────────────────────┘
```

### Key Components

| Component | Role |
|-----------|------|
| **sBPMN Ontology** | Process classes (Task, Gateway, Event) in OWL/Turtle |
| **CTO Ontology** | Telecom domain elements (HLR, network nodes) |
| **AgentFLOW Ontology** | Agent extensions (AgenticTask, GuardrailGateway) |
| **SHACL Shapes** | Pre-flight structural validation |
| **Named Graphs** | TBox/ABox separation — definitions vs runtime state |
| **Goose Recipes** | Fresh-context LLM task execution |
| **Bash Engine** | Stateless orchestration loop |

## Quick Start

### Prerequisites

- Java 17+
- Apache Jena 6.x (`riot`, `shacl`, `fuseki-server`)
- `jq`, `curl`, `bash 4+`
- Goose CLI

### Install & Start Fuseki

```bash
# If using the fuseki skill:
fuseki setup
fuseki start
```

### Run Demo 1: SIM Card Activation (Telecom)

```bash
make demo-telecom
```

This runs a SIM activation workflow with LLM-based request classification,
an ExclusiveGateway that routes CRITICAL requests to escalation, and
CTO-linked HLR provisioning.

### Run Demo 2: Git Push Safety

```bash
# Terminal 1: Start the demo (blocks at approval gateway)
make demo-git-push

# Terminal 2: Inject approval
make approve PROCESS=ProcInst_GitPush_001 VALUE=APPROVED
```

This runs the Git Push Safety guardrail as a process graph. The LLM
executes scan, report, and README check tasks. A GuardrailGateway
**blocks execution** until a human approves or denies the push.

### GUI Walkthrough

See [demo/walkthrough/README.md](demo/walkthrough/README.md) for a
step-by-step guide using Fuseki's YASGUI web interface with pre-built
SPARQL queries.

## Ontology

### Class Hierarchy

```
sbpmnc:Task
├── sbpmnc:UserTask, ScriptTask, ServiceTask, ...
└── agentflow:AgenticTask              ← LLM actor, stateless, recipe-driven

sbpmnc:Gateway
├── sbpmnc:ExclusiveGateway            ← XOR routing
└── sbpmnc:ComplexGateway
    └── agentflow:GuardrailGateway     ← enforcement checkpoint + optional approval

sbpmn:ProcessDefinition
└── agentflow:AgenticProcess           ← process with LLM-executed tasks
```

### Named Graphs

| Graph | Content | Mutated? |
|-------|---------|----------|
| `.../graphs/definitions` | TBox: process blueprints, CTO schema | ❌ Read-only |
| `.../graphs/runtime` | ABox: instances, variables, audit trail | ✅ SPARQL UPDATE |

## Project Structure

```
agentflow/
├── engine/
│   ├── orchestrate.sh          # Main engine loop
│   └── config.env              # Fuseki endpoint, dataset, timeouts
├── ontology/
│   ├── sbpmn.ttl               # sBPMN classes & properties
│   ├── cto.ttl                 # Telecom domain ontology
│   ├── agentflow.ttl           # AgentFLOW extensions
│   └── shapes/                 # SHACL validation constraints
├── demo/
│   ├── sim-activation/         # Demo 1: SIM Card Activation
│   ├── git-push-safety/        # Demo 2: Git Push Safety
│   └── walkthrough/            # GUI walkthrough + SPARQL queries
├── scripts/
│   ├── load_ontology.sh        # Load TBox + ABox into Fuseki
│   └── check_prerequisites.sh  # Verify dependencies
├── docs/
│   ├── architecture.md
│   └── decisions.md            # Key design decisions
└── Makefile                    # make demo-telecom, demo-git-push, approve
```

## Key Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Graph store | Apache Jena Fuseki | RDF/OWL standards, SPARQL 1.1, built-in YASGUI |
| Orchestrator | Bash + curl + jq | Zero heavy dependencies, UNIX composable |
| Edge properties | Turtle-star (RDF 1.2) | Gateway conditions without reification |
| TBox/ABox | Named graphs | Write-protection for definitions |
| Task executor | Goose CLI | Ralph Loop — fresh context per task |
| Gateway routing | SPARQL-native | Deterministic, auditable, no external eval |

## License

Copyright 2025 Evan Zhang

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
implied. See the License for the specific language governing
permissions and limitations under the License.

See [LICENSE](./LICENSE) for the full text.
