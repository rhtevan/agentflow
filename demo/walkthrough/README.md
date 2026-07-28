# AgentFLOW GUI Walkthrough

This walkthrough uses **Fuseki's built-in YASGUI** web interface to
inspect the process graph in real time while the engine runs.

## Setup

1. **Start Fuseki** (if not running):
   ```bash
   fuseki start
   ```

2. **Load a demo** (choose one):
   ```bash
   make load DEMO=sim-activation
   # or
   make load DEMO=git-push-safety
   ```

3. **Open Fuseki UI** in your browser:
   ```
   http://localhost:3030/#/dataset/agentflow/query
   ```

4. **Run the engine with `--pause`** (pauses after each task):
   ```bash
   bash engine/orchestrate.sh --demo demo/sim-activation --pause
   ```

## Pre-Built Queries

Copy-paste these queries into the YASGUI editor at each pause point.

| Query | File | What It Shows |
|-------|------|---------------|
| 1 | [01_show_process_topology.rq](queries/01_show_process_topology.rq) | All nodes and edges in the process definition |
| 2 | [02_show_active_token.rq](queries/02_show_active_token.rq) | Where the process token currently sits |
| 3 | [03_show_task_history.rq](queries/03_show_task_history.rq) | Completed tasks with outputs |
| 4 | [04_show_gateway_decision.rq](queries/04_show_gateway_decision.rq) | Transition chain — which path was taken |
| 5 | [05_show_cto_elements.rq](queries/05_show_cto_elements.rq) | CTO network elements (Demo 1 only) |
| 6 | [06_show_process_variables.rq](queries/06_show_process_variables.rq) | All accumulated process variables |

## Walkthrough: Demo 1 (SIM Activation)

### Before starting the engine

1. Run **Query 1** → See the full process topology:
   `StartEvent → ClassifyRequest → SeverityCheck → (Escalate | Provision) → LogCompletion → EndEvent`

2. Run **Query 5** → See the HLR network element (Nokia, Toronto, ACTIVE)

3. Run **Query 2** → Token is at `StartEvent`

### After each pause

4. Run **Query 2** → Watch the token advance through each node
5. Run **Query 6** → Watch process variables accumulate
   (severity, reason, escalation_ticket_id, etc.)

### After the gateway

6. Run **Query 4** → See the transition chain showing which path was taken

### After completion

7. Run **Query 3** → Full execution history with all task outputs
8. Run **Query 6** → All accumulated variables from the entire run

## Walkthrough: Demo 2 (Git Push Safety)

### Before starting

1. Run **Query 1** → See the linear chain with GuardrailGateway
2. Run **Query 2** → Token at StartEvent

### During execution (4 preparation tasks)

3. After each pause, run **Query 6** → Watch findings accumulate
4. Run **Query 3** → See tasks completing one by one

### At the GuardrailGateway (engine blocks)

5. Run **Query 2** → Token is at `Human Push Approval`
6. Run **Query 6** → See all findings, report, README status
7. **Inject approval** from another terminal:
   ```bash
   make approve PROCESS=ProcInst_GitPush_001 VALUE=APPROVED
   ```
8. Run **Query 6** again → See `approval_status = APPROVED` appear

### After completion

9. Run **Query 3** → Full history including push result and override log
10. Run **Query 4** → Transition chain through all 8 nodes
