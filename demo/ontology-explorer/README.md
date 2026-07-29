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

### 2. Serve the visualizer

```bash
python3 -m http.server 8080 -d demo/ontology-explorer
```

Then open `http://localhost:8080` in your browser.

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
Fuseki 6.1.0 handles CORS out of the box — no extra configuration needed.

## Dependencies (CDN, no install required)

- [Cytoscape.js](https://js.cytoscape.org/) — graph rendering
- [dagre](https://github.com/dagrejs/dagre) — hierarchical layout algorithm
- [cytoscape-dagre](https://github.com/cytoscape/cytoscape.js-dagre) — layout plugin

## Verification (for automated or manual testing)

### Prerequisites

```bash
# Ensure Fuseki is running with demo data loaded
fuseki start
make clean
make load DEMO=sim-activation

# Serve the visualizer
python3 -m http.server 8080 -d demo/ontology-explorer &
```

### Test 1: Page Loads Successfully

- Open `http://localhost:8080` in browser
- **PASS:** Page title is "AgentFLOW Process Visualizer"
- **PASS:** Header bar shows "AgentFLOW" on the left and controls on the right
- **PASS:** Status text (top-right) shows "Loaded: N nodes, N edges" (not "Error")
- **FAIL:** Page shows "Error: ..." or "Connecting to Fuseki..." indefinitely

### Test 2: Process Flow View Renders

- The default view is "Process Flow"
- **PASS:** Graph area displays nodes connected by directed edges (arrows)
- **PASS:** At least 5 distinct nodes are visible
- **PASS:** Nodes have different colors:
  - Green circle (StartEvent)
  - Blue rounded rectangles (AgenticTask)
  - Orange or red diamond (Gateway)
  - Red circle (EndEvent)
- **PASS:** Edges flow generally left-to-right (dagre layout)
- **PASS:** Node labels are visible below each node
- **FAIL:** Graph area is empty, or all nodes are the same color

### Test 3: Node Inspection (click interaction)

- Click on any blue (AgenticTask) node in the graph
- **PASS:** Right sidebar "Node Details" section updates with:
  - **ID** — short name of the node
  - **Label** — human-readable task name
  - **Type** — shows the sBPMN/AgentFLOW class name
  - **Recipe** — shows the recipe filename (e.g., `classify_request.yaml`)
- Click on empty canvas area
- **PASS:** Node Details resets to "Click a node to inspect"
- **FAIL:** Sidebar doesn't update, or fields are empty

### Test 4: Process Variables Display

- Check the right sidebar "Process Variables" section
- **PASS:** Table shows at least 3 variables with Name and Value columns
- **PASS:** Variable names include `msisdn`, `imsi`, `request_text` (for sim-activation demo)
- **FAIL:** Shows "No variables yet" despite data being loaded

### Test 5: Runtime State (active token)

- Look for a node with a gold/yellow border (thicker than other nodes)
- **PASS:** Exactly one node has a gold border — this is the active token position
- Note: If the process has completed, no node will have a gold border and
  completed nodes will appear dimmed — this is also correct behavior

### Test 6: Ontology Classes View

- Select **Ontology Classes** from the dropdown (top-left controls)
- **PASS:** Graph re-renders with a different set of nodes
- **PASS:** Significantly more nodes than the Process Flow view (50+ from sBPMN alone)
- **PASS:** Three color groups visible:
  - Blue nodes = sBPMN classes
  - Orange nodes = CTO classes
  - Pink/red nodes = AgentFLOW extension classes
- **PASS:** Edges represent `rdfs:subClassOf` relationships
- **FAIL:** Graph doesn't change when switching views

### Test 7: Refresh and Auto-Poll

- Click the **⟳ Refresh** button
- **PASS:** Status text briefly shows "Loading..." then updates with node/edge count
- Click **▶ Auto-Poll** button
- **PASS:** Button text changes to "⏸ Stop Poll" and turns red/highlighted
- **PASS:** Status text updates periodically (every 3 seconds)
- Click **⏸ Stop Poll** to stop
- **PASS:** Button reverts to "▶ Auto-Poll"

### Cleanup

```bash
# Stop the HTTP server
kill %1 2>/dev/null || true
```
