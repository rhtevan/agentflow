# Demo 2: Git Push Safety

A developer workflow demonstrating guardrails-as-graphs: the Git Push
Safety guardrail (AgentFS Guardrail #9) implemented as a deterministic
process graph with a human-in-the-loop GuardrailGateway.

## Core Thesis

> **Instructions are suggestions. Graph edges are law.**
>
> In text-based guardrails, the LLM can skip the security scan.
> In AgentFLOW, the token physically cannot reach `Execute Push`
> without traversing through `Scan Secrets`, `Generate Report`,
> and `Human Approval`. There is no edge that bypasses them.

## Process Flow

```
StartEvent
    │
    ▼
AgenticTask: Stage Changes            ← Goose: capture diff
    │
    ▼
AgenticTask: Scan Secrets              ← Goose: scan for secrets, PII
    │
    ▼
AgenticTask: Generate Report           ← Goose: format security report
    │
    ▼
AgenticTask: Check README              ← Goose: check staleness
    │
    ▼
GuardrailGateway: Human Approval       ← ALWAYS BLOCKS
    │                    │
    │ (APPROVED)         │ (DENIED / TIMEOUT)
    ▼                    ▼
AgenticTask:         EndEvent:
  Execute Push         Aborted
    │
    ▼
AgenticTask:
  Log Push Result                      ← Records [OVERRIDE] if findings
    │
    ▼
EndEvent: Completed
```

## Object Under Process

- **Git Repository**: local working directory
- **Remote**: `origin`
- **Branch**: `main`

## Recipes

| Recipe | Purpose |
|--------|---------|
| `git_stage.yaml` | Capture staged files and diff summary |
| `git_scan_secrets.yaml` | Scan for secrets, API keys, PII, hardcoded paths |
| `git_security_report.yaml` | Format Pre-Push Security Report |
| `git_readme_check.yaml` | Check if README needs updating |
| `git_push.yaml` | Generate push result payload |
| `git_log_result.yaml` | Log outcome, record overrides |

## Run

```bash
# Terminal 1: Start the demo (will block at approval gateway)
make demo-git-push

# Terminal 2: Inject approval decision
make approve PROCESS=ProcInst_GitPush_001 VALUE=APPROVED
# or
make approve PROCESS=ProcInst_GitPush_001 VALUE=DENIED
```

## What It Proves

- **Guardrails as graphs** — the LLM cannot skip the security scan
- **Human-in-the-loop** — GuardrailGateway blocks until human decides
- **Override auditing** — `[OVERRIDE]` recorded when findings were present
- **Topology enforcement** — no `sbpmn:nextTask` edge from Stage to Push
- **Same engine, different workflow** — only the TBox definitions differ
