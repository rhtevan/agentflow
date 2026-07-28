# Demo 1: SIM Card Activation

A telecom SIM activation workflow demonstrating sBPMN process topology,
CTO network element integration, ExclusiveGateway routing, and Goose
recipe execution.

## Process Flow

```
StartEvent
    │
    ▼
AgenticTask: Classify Request         ← Goose: classify severity
    │
    ▼
ExclusiveGateway: Severity Check      ← SPARQL: severity == "CRITICAL"?
    │                    │
    │ (CRITICAL)         │ (default)
    ▼                    ▼
AgenticTask:          AgenticTask:
  Escalate Issue        Provision HLR  ← CTO-linked to HLR-TO-01
    │                    │
    └────────┬───────────┘
             ▼
AgenticTask: Log Completion
             │
             ▼
         EndEvent
```

## Object Under Process

- **SIM Card**: MSISDN `+14165550199`, IMSI `302720123456789`
- **HLR Node**: `HLR-TO-01` (Nokia, Toronto DC-1, ACTIVE)

## Recipes

| Recipe | Inputs | Outputs |
|--------|--------|---------|
| `classify_request.yaml` | msisdn, imsi, request_text | severity, reason |
| `escalate_issue.yaml` | msisdn, imsi, severity, reason | escalation_ticket_id, priority, team |
| `provision_hlr.yaml` | msisdn, imsi | provisioning_status, hlr_node |
| `log_completion.yaml` | msisdn, imsi, severity, reason | audit_record, timestamp |

## Run

```bash
make demo-telecom
```

## What It Proves

- sBPMN process topology enforces step ordering
- ExclusiveGateway routes deterministically via SPARQL
- CTO network element linked to provisioning task
- Each task runs in fresh Goose context (Ralph Loop)
- All state stored in Jena ABox
