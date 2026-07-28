# Demo 3: Ontology Explorer & Process Visualizer

An interactive browser-based visualizer for AgentFLOW process
topology and ontology class hierarchies, powered by Cytoscape.js.

## Features

- **Process Flow View** — renders sBPMN process topology as a left-to-right
  flowchart (dagre layout) with color-coded node types
- **Ontology View** — renders the class hierarchy (sBPMN + CTO + AgentFLOW)
  as a directed graph
- **Live Runtime State** — polls Fuseki for active token position,
  completed tasks, and process variables
- **Node Inspector** — click any node to see its type, label, recipe,
  and approval requirements
- **Auto-Poll** — watch the process execute in real time as the engine
  advances tokens

## Node Color Legend

| Color | Node Type |
|-------|----------|
| 🟢 Green | StartEvent |
| 🔴 Red | EndEvent |
| 🔵 Blue | AgenticTask |
| 🟠 Orange | ExclusiveGateway |
| ❤️ Pink | GuardrailGateway |
| ⭐ Gold border | Active Token |
| Dimmed | Completed |

## Quick Start

### 1. Start Fuseki and load a demo

```bash
fuseki start
make load DEMO=sim-activation
```

### 2. Open the visualizer

Open in your browser:
```
file:///path/to/agentflow/demo/ontology-explorer/index.html
```

Or serve it locally:
```bash
cd demo/ontology-explorer
python3 -m http.server 8080
# Open http://localhost:8080
```

### 3. Watch a demo run in real time

1. Open the visualizer in your browser
2. Click **▶ Auto-Poll** to start polling Fuseki every 3 seconds
3. In another terminal, run the engine:
   ```bash
   make demo-telecom
   ```
4. Watch the token advance through the graph — nodes turn gold (active)
   then dim (completed)

### 4. Switch to ontology view

Select **Ontology Classes** from the dropdown to see the full class
hierarchy:
- Blue nodes = sBPMN classes (startEvent, task, exclusiveGateway...)
- Orange nodes = CTO classes (Network, Device, PhysicalInfrastructure...)
- Pink nodes = AgentFLOW classes (AgenticTask, GuardrailGateway...)

## Architecture

```
Browser (index.html)
    │
    │ SPARQL queries via fetch()
    ▼
Fuseki SPARQL Endpoint (localhost:3030)
    │
    ├── TBox (definitions graph) → process topology, ontology classes
    └── ABox (runtime graph) → token position, task status, variables
```

Zero server-side code. Pure client-side JavaScript querying Fuseki directly.

## Dependencies (CDN)

- [Cytoscape.js](https://js.cytoscape.org/) — graph rendering
- [dagre](https://github.com/dagrejs/dagre) — hierarchical layout algorithm
- [cytoscape-dagre](https://github.com/cytoscape/cytoscape.js-dagre) — layout plugin
