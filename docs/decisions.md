# Key Design Decisions

Consolidated record of architectural decisions made during AgentFLOW design.

---

## 1. Apache Jena over Neo4j

**Context:** The initial design used Neo4j (property graph) with Cypher queries.

**Decision:** Switched to Apache Jena Fuseki (RDF triple store) with SPARQL.

**Rationale:**
- OWL, SHACL, SPARQL are W3C standards — not proprietary
- Formal TBox/ABox separation via named graphs
- SHACL provides standards-based structural validation
- Turtle-star (RDF 1.2) gives property-graph ergonomics
- Fuseki is lightweight, runs standalone, includes YASGUI web UI

---

## 2. Bash over Python

**Context:** Most agent orchestrators use Python frameworks.

**Decision:** Implement the engine in Bash with `curl` and `jq`.

**Rationale:**
- Zero heavy dependencies — no virtualenvs, pip, ORMs
- UNIX composable — small tools communicating via JSON
- Appropriate for an experiment / PoC
- The engine is a simple poll loop, not a complex application
- If it grows beyond bash, the design is clear enough to port

---

## 3. Turtle-star for Edge Properties

**Context:** Gateway conditions and audit metadata need to be attached
to relationship edges, not just nodes.

**Decision:** Use RDF 1.2 Turtle-star inline annotations (`{| ... |}`).

**Rationale:**
- Avoids verbose RDF reification (intermediate nodes)
- Standard syntax (not a proprietary extension)
- Apache Jena 4.7+ supports RDF-star/SPARQL-star natively
- Clean, readable process definitions

---

## 4. Named Graphs for TBox/ABox Separation

**Context:** Process definitions (static) and runtime state (dynamic)
could live in the same graph or be separated.

**Decision:** Use named graphs — `definitions` (TBox, read-only) and
`runtime` (ABox, read/write).

**Rationale:**
- Engine SPARQL UPDATE queries can never corrupt process definitions
- Clean state reset: `DROP GRAPH <.../runtime>` and reload
- SHACL can validate ABox against TBox selectively
- Query performance: graph-scoped queries scan only relevant subset

---

## 5. Goose as Universal Task Executor

**Context:** AgenticTask nodes need an LLM executor. Options included
direct API calls, LangChain, or the Goose CLI.

**Decision:** Use Goose CLI (`goose run --recipe`) as the task executor.

**Rationale:**
- Ralph Loop pattern — fresh context per task, no accumulation
- Structured I/O via recipe parameters and JSON output
- Already installed and configured in the development environment
- Recipe YAML format provides declarative task definitions

---

## 6. SPARQL-native Gateway Routing

**Context:** Gateway conditions could be evaluated by the bash script
(using `jq` against JSON), by the LLM, or by SPARQL.

**Decision:** Evaluate gateway conditions via SPARQL against ABox
variables, with bash fallback for comparison operators.

**Rationale:**
- Deterministic — same inputs always produce same routing
- Auditable — evaluation recorded in ABox transition trail
- No LLM involvement in routing decisions
- Conditions stored declaratively on graph edges (Turtle-star)

---

## 7. Goose Coupling Boundary

**Context:** The engine uses Goose CLI for task execution. This creates
a coupling that prevents agent-agnostic portability.

**Decision:** Accept the coupling for the experimental phase. Isolate it
to two locations: one ontology property (`agentflow:recipe`) and one
engine function (`execute_agentic_task`).

**Rationale:**
- The ontology is agent-agnostic except for one property
- Swapping to another agent requires rewriting ~50 lines + recipe files
- Everything else (topology, SPARQL, SHACL, gateway routing) is portable
- Documenting the boundary makes future portability straightforward
- Acceptable trade-off for a PoC

---

## 8. AgenticTask as a New Task Type

**Context:** Should the LLM-executed task be modeled as a subclass of
UserTask, ScriptTask, or a new type?

**Decision:** Define `agentflow:AgenticTask` as a sibling of UserTask
and ScriptTask under `sbpmnc:Task`.

**Rationale:**
- UserTask assumes persistent memory across tasks — agents don't have this
- ScriptTask implies deterministic output — LLMs are stochastic
- An LLM agent is genuinely new: stateless, recipe-driven, non-deterministic
- Honest ontological modeling over force-fitting into existing types

---

## 9. GuardrailGateway as ComplexGateway Subclass

**Context:** Should enforcement checkpoints be ExclusiveGateway
subclasses or a separate type?

**Decision:** Define `agentflow:GuardrailGateway` as a subclass of
`sbpmnc:ComplexGateway`.

**Rationale:**
- BPMN ComplexGateway is explicitly for "custom activation semantics"
- GuardrailGateway combines Event-Based (wait for approval) and
  Exclusive (evaluate condition) behaviors — a hybrid BPMN doesn't have
- Self-evaluation mode behaves like XOR; approval mode adds polling
- Engine implementation difference is one `if` statement
- Semantic classification enables SPARQL discovery of all guardrail points
