# Project Memories

<!-- Experiences and learnings specific to this project. Newest entries first. -->

## v0.1.0 Retrospective — 2026-07-28

### What Went Well

- Constitution-first design — starting with the *why* (stochastic LLM behavior,
  context degradation) before the *what* kept the project focused.
- Iterative design — evolved through dialogue (Neo4j → Jena, fake ontologies →
  real standards, 3 gateways → 1 GuardrailGateway in Demo 2) before code.
- Test-before-refactor — writing the test suite before the namespace refactor
  caught issues immediately.
- Simplification pressure — trimmed from 8 phases to 3, cut premature ADRs/CI.
- Core thesis proved out — LLM cannot skip graph nodes, gateway routing is
  deterministic, human-in-the-loop works.

### What Went Wrong

- Invented ontologies instead of using real sBPMN/CTO — required full refactor.
- Pushed without Guardrail #9 three times — violated the rule AgentFLOW was
  designed to enforce. Proves the core thesis: text instructions are unreliable.
- SPARQL PREFIX declarations missed repeatedly — every embedded SPARQL query in
  bash/SHACL needs its own PREFIX. Single biggest source of bugs.
- `test_structure.sh` didn't load its own data — assumed Fuseki had data loaded.
- Goose's built-in Git Push Safety refused to run `git_push.yaml` — had to rename
  recipe to "Deployment Status Generator".
- Recipe sessions polluted Goose Desktop — needed post-test cleanup.
- Claimed to "visually confirm" output without having visual capabilities.

### Key Technical Learnings

- Use real standard ontologies from day one — avoid costly refactors.
- Every embedded SPARQL query needs its own PREFIX declarations.
- Goose wraps output in markdown fences even when asked for JSON-only.
- `owl:imports` is declarative, not an HTTP fetch — don't assume auto-resolution.
- Test scripts must be self-contained — load their own data, don't assume state.
- Agent-generated recipe sessions need cleanup — design for ephemeral session hygiene.

### Risks & Technical Debt

- Goose CLI coupling — isolated to one module, documented portability path.
- `example.org` namespace for `agentflow:` — needs real URI for production.
- No parallel gateway or sub-process support — documented as non-goals for PoC.
- SHACL shapes are basic — sufficient for PoC, not comprehensive.
- Fuseki runs in-memory — data lost on restart, acceptable for demos.

### Recommendations for Next Phase

- Browser-test Demo 3 using Computer Use agent (verification checklist ready).
- Register `agentflow:` under a real namespace if project goes beyond experiment.
- Extract engine lib functions from monolithic `orchestrate.sh` when adding features.
- Add parallel gateway support for real-world workflows.
- Consider AgentFLOW as an AgentFS skill (`agentflow-run`).
- Verify Fuseki's SPARQL-star support for gateway condition queries.

---

## 2026-07-28 — Technical Observations

- Goose CLI wraps LLM output in markdown code fences (```json ... ```) even when
  asked for JSON-only. The engine needs multi-strategy JSON extraction: strip
  fences → grep single-line → extract multiline block.

- Goose recipe `prompt` field is required for headless (`--quiet`) mode. Having
  only `instructions` causes "no text provided" error. Always include both.

- Goose recipe optional parameters must have `default` values or validation fails.

- Goose's built-in Git Push Safety guardrail (Guardrail #9 from AgentFS) can
  interfere with recipes that mention "git push". The `git_push.yaml` recipe
  had to be renamed to "Deployment Status Generator" to prevent Goose from
  refusing to execute it.

- `local` keyword in bash cannot be used outside functions. The engine loop
  is not inside a function, so variables there must not use `local`.

- When refactoring RDF namespaces, every layer must be updated: ontology files,
  SHACL shapes (including embedded SPARQL queries), demo data files, engine
  SPARQL queries, walkthrough queries, Makefile approval targets, and test
  scripts. Missing even one PREFIX declaration in an embedded SPARQL query
  causes silent failures.

- SHACL shapes with `sh:SPARQLTarget` need PREFIX declarations inside the
  embedded SPARQL string — they don't inherit prefixes from the Turtle file.

- The `stain/jena-fuseki` Docker image has entrypoint script issues with
  command-line arguments. Running Fuseki natively as a systemd user service
  is more reliable and gives access to all CLI tools (`riot`, `shacl`) on
  the host PATH.

- Apache Jena 6.1.0 is the current latest version (not 5.x). The download
  mirror at `https://dlcdn.apache.org/jena/binaries/` lists available versions.

- `owl:imports` in OWL ontologies is a logical declaration, not an automatic
  HTTP fetch. Jena/Fuseki does not resolve `owl:imports` URIs when loading
  data via the Graph Store Protocol. Standard ontologies (OWL, RDFS, XSD)
  work because Jena treats their namespace URIs as opaque strings matched
  by equality, not because it fetches their definitions.

- sBPMN uses lowercase class names (`startEvent`, `endEvent`, `exclusiveGateway`,
  `complexGateway`, `task`, `serviceTask`) while our AgentFLOW extensions use
  CamelCase (`AgenticTask`, `GuardrailGateway`, `ProcessInstance`).
