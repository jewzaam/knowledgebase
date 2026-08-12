# Mermaid Diagram Rendering Behaviors

Observed behaviors and quirks in Mermaid diagram rendering that affect layout, appearance, and parsing. These facts were discovered while producing reference architecture diagrams for a Kubernetes operator deployment on OpenShift (source repo is not public).

For prescriptive rules on how to structure diagrams, see [standards/common/documentation-diagrams.md](https://github.com/jewzaam/standards/blob/main/common/documentation-diagrams.md).

## Node Placement and Relationship Definitions

When a relationship (arrow) is defined inside a subgraph block, Mermaid pulls the connected node INTO that subgraph during rendering, even if the node was declared outside. This causes unexpected placement.

Example: An "Enterprise Ingress" node declared outside an "OpenShift Cluster" subgraph will render inside the cluster if an arrow from Ingress to a Route (inside the cluster) is defined within the cluster's subgraph block.

**Fix:** Declare all nodes inside their intended subgraphs. Define all relationships outside all subgraph blocks. This gives explicit control over node placement independent of connection topology.

## Style Color Inheritance

When `style` is applied to a subgraph with a dark `fill` color, child node text defaults to dark (black or grey). The `color:#fff` property from the parent subgraph style does NOT inherit to child nodes.

Each node or subgraph that uses a dark background must have `color:#fff` set explicitly in its own style declaration. Light pastel backgrounds (e.g., `fill:#e3f2fd`) avoid this issue but render poorly in many viewers and look washed out.

## Subgraph Nesting Contrast

When a parent subgraph and its children use the same fill color, the children are visually invisible against the parent background. The child subgraph borders blend into the parent fill.

Use a slightly different shade for nested subgraphs. Example: parent `fill:#0d47a1` (darker), children `fill:#1565c0` (lighter) — same color family, different luminance. The delta should be approximately 2 steps on a material design color scale. This provides visual contrast without requiring a separate legend entry.

## Legend Rendering

A `subgraph Legend["Legend"]` containing styled nodes is the idiomatic way to add a color key to Mermaid diagrams. Legend nodes are regular Mermaid nodes with `style` applied.

The legend subgraph renders in the flow layout like any other subgraph. Position it at the bottom of the flowchart definition to keep it out of the main diagram area. Legend nodes should NOT have arrows connecting them to diagram nodes — they are display-only.

## Subgraph Label Quoting

Subgraph labels containing special characters (parentheses, colons, slashes) must be quoted:

```text
subgraph Name["Label with (special) chars"]
```

Unquoted labels with these characters cause Mermaid parse errors. This applies to subgraph names only — node labels have different quoting rules.

## Cross-Reference

Prescriptive companion: [standards/common/documentation-diagrams.md](https://github.com/jewzaam/standards/blob/main/common/documentation-diagrams.md)

Knowledgebase repo: <https://github.com/jewzaam/knowledgebase.git/>
