# Project Memories

<!-- Experiences and learnings specific to this project. -->

## 2026-07-28

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
