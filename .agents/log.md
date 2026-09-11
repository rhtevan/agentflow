# Directory Update Log

<!-- Append-only. Newest entries at top. -->

## 2026-09-11 11:15
- Synced AGENTS.md template v5.5.0 → v5.9.0 (project scope)

- Created AGENTS.md at project root (scope: project).

## 2026-09-08 09:15
- Synced AGENTS.md template v3.7 → v5.5.0 (project scope)

- Created AGENTS.md at project root (scope: project).

## 2026-07-28 23:39
- Completed all pending items: expected_output.txt, SHACL validation, walkthrough queries, decisions.md, MEMORY.md
- Fixed test_structure.sh to load its own data (was failing with empty Fuseki)
- Added post-test cleanup: temp files + ephemeral Goose recipe sessions
- make clean now removes /tmp/agentflow_* temp files
- Recorded v0.1.0 retrospective in MEMORY.md
- All 4 test suites pass (27/27 assertions)

## 2026-07-28 18:43
- Namespace refactor: replaced example.org with real sBPMN/CTO namespace URIs
- Deleted local ontology/sbpmn.ttl and ontology/cto.ttl — fetched from GitHub at load time
- Moved runtime concepts (ProcessInstance, TaskInstance, etc.) to agentflow: namespace
- Aligned class names to real sBPMN lowercase convention
- Added test suite: test_syntax.sh, test_namespaces.sh, test_structure.sh, test_engine.sh
- Added Makefile targets: make test, make test-fast
- Created demo/ontology-explorer/ — Cytoscape.js process visualizer + ontology class viewer
- Both demos pass end-to-end with refactored namespaces

## 2026-07-28 11:05
- Phase 3 complete: documentation, walkthrough, and packaging
- Created README.md (project overview, quick start, architecture)
- Created docs/architecture.md (engine loop, TBox/ABox, class hierarchy)
- Created docs/decisions.md (9 consolidated design decisions)
- Created demo/walkthrough/README.md (GUI walkthrough guide)
- Created 6 SPARQL walkthrough queries (topology, token, history, gateway, CTO, variables)
- Created demo/sim-activation/README.md and demo/git-push-safety/README.md
- Created scripts/check_prerequisites.sh and scripts/cleanup.sh
- Created Makefile with 7 targets (check, load, validate, clean, demo-telecom, demo-git-push, approve)
- Created VERSION (0.1.0), LICENSE
- Updated .gitignore (engine/config.env, temp files)

## 2026-07-28 10:30
- Phase 2 complete: engine core + both demos passing end-to-end
- Created engine/orchestrate.sh (main engine loop with SPARQL polling)
- Created engine/config.env.example
- Created 4 SIM Activation recipes (classify, escalate, provision, log)
- Created 6 Git Push Safety recipes (stage, scan, report, readme, push, log)
- Demo 1 (SIM Activation): CRITICAL path runs end-to-end
- Demo 2 (Git Push Safety): approval gateway + human-in-the-loop working

## 2026-07-28 10:15
- Phase 1 complete: ontology files created and validated
- Created ontology/sbpmn.ttl (minimal sBPMN subset — 223 lines)
- Created ontology/cto.ttl (minimal CTO for Demo 1 — 67 lines)
- Created ontology/agentflow.ttl (AgentFLOW extensions — 157 lines)
- Created ontology/shapes/process_shapes.ttl (SHACL process constraints)
- Created ontology/shapes/cto_shapes.ttl (SHACL CTO constraints)
- Created scripts/load_ontology.sh
- All 5 .ttl files pass riot --validate

## 2026-07-27 18:54

- Created AGENTS.md at project root.

## 2026-07-25 23:53
- Renamed project directory from `agentctl` to `agentflow` (AgentFLOW / agent-flow).
- Populated SOUL.md with AgentFLOW project identity and agent-x trilogy context.

## 2026-07-25 23:23
- Created AGENTS.md at project root.

- Initialized .agents/ directory structure (mode: project).
