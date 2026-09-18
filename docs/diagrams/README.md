# Diagrams

Each `.md` file is a self-contained Mermaid diagram with explanation. View in any Markdown renderer that supports Mermaid (GitHub, GitLab, VS Code with the Mermaid extension, MkDocs Material, Obsidian).

| Diagram | Shows |
|---|---|
| [01-overall-system.md](01-overall-system.md) | The whole picture: tooling, environments, services, infra |
| [02-environment-interactions.md](02-environment-interactions.md) | DEV / CI / DIST / CUSTOMER environments and the trust boundaries between them |
| [03-tools-interactions.md](03-tools-interactions.md) | The five tools (Helm, kubectl, Drone, gsutil, git) and what they do |
| [04-runtime-traffic-flow.md](04-runtime-traffic-flow.md) | A request's path through the cluster (Studio + JDBC) |
| [05-data-flow.md](05-data-flow.md) | Which datastore holds what, which services touch each |
| [06-release-pipeline.md](06-release-pipeline.md) | Sequence diagram: maintainer → tag → Drone → GCS → customer |

## Conventions

- Subgraphs match logical layers (edge / API / data / workflow / query).
- Solid arrows `-->` are sync/network calls.
- Dashed arrows `-.->` are "uses" / weaker relationships.
- Round-edged shapes (`(...)`) are external/managed services or data stores.
- Curly braces `{...}` denote middlewares or decision points.
