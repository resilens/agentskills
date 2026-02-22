---
name: c4-diagrams
description: Use for architectural analysis and documentation; create C4 PlantUML diagrams with clear actors, system boundaries, containers, components, and relationships.
license: Apache-2.0
metadata:
  author: Stephan
  version: "0.1"
allowed-tools:
  - scripts/render.sh
  - scripts/build_explorer.sh
---

# C4 Diagrams with PlantUML

## When to use this skill

Use this skill when you need to:
- Create C4 context/container/component/code diagrams in PlantUML
- Capture actors, systems, containers, and their relationships for an architecture view
- Ask for or refine inputs like primary actors, system boundaries, key containers, and data flows
- Maintain diagrams in `$REPO_ROOT/docs/diagrams` by default. You may ask the
  user if she wants to have a `./diagrams/` folder directly next to some other
  files.
  
## Overview

For a code repository, a user may ask to create and tune architectural diagrams
using **C4-PlantUML**. [C4 documentation](https://c4model.com/) C4 is a developer-friendly method
for visualizing software architecture through four hierarchical levels of
abstraction: Context, Container, Component, and Code. This approach
progressively adds detail, starting with a high-level overview of the system's
interactions and zooming into finer-grained components to communicate design
clearly. PlantUML is an open-source tool that allows users to create various
types of diagrams, including UML diagrams, from simple plain-text descriptions.

[C4-PlantUML](https://github.com/plantuml-stdlib/C4-PlantUML/blob/master/README.md) is a tool that combines the benefits of PlantUML and the C4
model. This skill covers includes, elements, relationships, and layout control
(global direction, forced edge direction, and element arrangement).

## Repo conventions

When used inside a repository:
- Store diagram sources in `$REPO_ROOT/docs/diagrams` only. Alternatively, us a
  `./diagrams/` folder directly next to some other files, if the user wants it
  that way.
- Subfolders are allowed and encouraged for scoping, e.g. `$REPO_ROOT/docs/diagrams/subsystem`.
- After creating or updating a `.puml` file, run `scripts/render.sh` on it to
  keep the output updated.
- Run `make smoke` in this skill directory after changing vendored C4 includes
  or `scripts/render.sh` to verify all C4 levels still render.
- For C4 sets, always generate an explorer HTML page with
  `scripts/build_explorer.sh`. Use flat mode for small repos and manifest mode
  for complex repos with multiple systems/containers/components.
- When a user asks for diagrams, always render a PNG by default as part of the
  response; treat rendering as implicit (do not ask separately).
- Honor user requests for SVG in addition to the default PNG.

## Default deliverables for C4 sets

When creating a C4 set, produce these artifacts by default:
- Individual rendered diagrams for:
  - System Landscape (if provided)
  - Per-system Context and Container
  - Per-container Component diagrams (only for architecturally important or
    confusing containers)
  - Deployment (if provided)
  - Sequence (if provided, one or more scenarios)
- One interactive explorer HTML page that supports:
  - Compact mode for small repos
  - Hierarchical navigation for complex repos (Landscape -> System ->
    Container -> Component)

Recommended naming conventions (manifest paths are authoritative):
- Small repos:
  - `<basename>-landscape.(svg|png)` (optional)
  - `<basename>-context.(svg|png)`
  - `<basename>-container.(svg|png)`
  - `<basename>-component.(svg|png)`
  - `<basename>-deployment.(svg|png)` (optional)
  - `<basename>-sequence.(svg|png)` (optional)
- Complex repos:
  - `<system>-context.(svg|png)`
  - `<system>-container.(svg|png)`
  - `<system>-deployment.(svg|png)` (optional)
  - `<system>-sequence-<scenario>.(svg|png)` (optional)
  - `<system>-<container>-components.(svg|png)`
- `<basename>-c4-explorer.html`

## C4 Planning Step (Do This Before Drawing)

Before generating diagrams, plan the C4 scope explicitly:
- Identify whether this repo is one system or multiple systems.
- If multiple systems, create a System Landscape and list the systems to model.
- For each system, create:
  - System Context
  - Container diagram
- For each system, list containers that actually need component diagrams.
- Create component diagrams only for containers that are architecturally
  important, complex, or unclear.
- Add Deployment and Sequence diagrams only where they clarify runtime behavior
  or a critical scenario.

## Always render, always validate

When using the skill, always remember:
- Always render a diagram to PNG after any edits. Make sure diagrams are always
  up to date.
- Once rendered, review the diagram visually using your built-in image viewer
  to validate that the request of the user has been adhered to, especially
  regarding layout:
  - it should be preferably landscape
  - no overlapping text labels
  - context/container diagrams should use the 2D space (avoid tall one-column
    "string" layouts)

### Layout stabilization rule (required for larger L1/L2 diagrams)

For **System Context** and **Container** diagrams with more than 4 elements
(actors/systems/containers), do not rely on generic `Rel(...)` edges alone.
Use this rule:

- Add `LAYOUT_LANDSCAPE()` before element declarations.
- Anchor at least 3 placements with directional relationships (`Rel_L`, `Rel_R`,
  `Rel_U`, `Rel_D`).
- Use `Lay_*` macros to spread peer elements and avoid single-column stacking.
- Re-render and adjust if the result is a tall/linear chain instead of a
  balanced 2D layout.

This rule is intentionally not required for very small diagrams (3-4 nodes),
where pure auto-layout is often fine.

## C4

### Core ideas

* **Goal:** communicate software architecture at *multiple zoom levels* with
  consistent, simple shapes.
* **Elements:** **Person**, **Software System**, **Container**, **Component**
  (+ **Code** level is optional).
* **Relationships:** directed connections with a short verb phrase (what talks
  to what, and why).

### Diagram levels & intent

* **System Landscape (optional):** where your system sits among other systems
  and user types.
* **Level 1 — System Context:** who uses the system and which neighboring systems it
  exchanges data with. *Scope:* one software system.
* **Level 2 — Container:** high-level building blocks (apps, services, UIs, DBs, queues)
  inside the system and their responsibilities/tech. *Scope:* deployable/runtime units.
* **Level 3 — Component:** internals of a single container: components (cohesive
  units—modules, services, controllers) and their dependencies. *Scope:* design boundaries
  within a container.
* **Level 4 — Code (optional):** selected classes/functions to illustrate a pattern.
  *Scope:* only when it clarifies.

### Element types

* **Person:** human actor (user or role). *Intent:* who benefits or initiates interactions.
* **Software System:** major system (the thing you’re building or external). *Intent:* sets
  the boundary for the other levels.
* **Container:** deployable/runtime unit (service, SPA, mobile app, DB, message broker).
  *Intent:* responsibilities + technology + interface.
* **Component:** cohesive chunk inside a container (e.g., “PaymentService,”
  “OrderController”). *Intent:* purpose + interface; hides implementation details.

### Relationships (edges)

* **Direction:** A → B (caller → callee / data flow direction).
* **Label:** short verb + purpose (e.g., “reads from,” “publishes events to”).
* **Tech/Protocol (optional):** HTTP/JSON, gRPC, JDBC, AMQP, etc.
* **Notes:** security constraints, sync/async, rate/volume if useful.

### Notation guidelines

* **Name + short description** on every box.
* **Responsibilities** over implementation detail.
* **Technology** on containers (and components if clarifying).
* **Boundaries:** group related elements (system boundary; container scope).
* **Keep it legible:** few boxes/lines per view; create more views instead of clutter.

### Supporting views (often used)

* **Dynamic diagram (scenario):** sequence of calls across elements for a use case.
* **Deployment diagram:** nodes (environments, VMs, k8s, serverless) and which containers
  run where.

## PlantUML

**PlantUML** is a text-based diagramming tool. Diagrams are written as plain
text and rendered into images (SVG, PNG, PDF). This makes diagrams easy to
version, review, and generate automatically.

### Why PlantUML
- **Version control friendly** (plain text)
- **Fast to write and modify**
- **Automatable** (CLI, CI/CD, Docker)
- **Wide diagram support**

### Supported diagram types
- Sequence diagrams
- Class diagrams
- Component and deployment diagrams
- Activity diagrams
- State diagrams
- C4-style architecture diagrams
- Mind maps and more

### Basic example

```plantuml
@startuml filename
Alice -> Bob: Hello
Bob --> Alice: Hi
@enduml
```


## Compile .puml files to SVG, PDF, PNGs 

In the `scripts/` folder of this skill, there is a convenience wrapper
`scripts/render.sh` to run it either locally or via Docker.

You can convert a PlantUML file to a raster or vector format as follows:

```bash
cat assets/simple.puml | scripts/render.sh -tpng -pipe > simple.png
``` 

```bash
cat assets/simple.puml | scripts/render.sh -tsvg -pipe > simple.svg
```

## Interactive Explorer Output

Use `scripts/build_explorer.sh` to produce a one-page C4 explorer.

### Mode 1: Small Repo Mode (flat flags, default/simple)

Use this when the repo maps cleanly to one main system and one primary
component diagram.

```bash
scripts/build_explorer.sh \
  --out docs/diagrams/payments-c4-explorer.html \
  --title "Payments Architecture C4" \
  --readme README.md \
  --landscape docs/diagrams/payments-landscape.svg \
  --context docs/diagrams/payments-context.svg \
  --container docs/diagrams/payments-container.svg \
  --component docs/diagrams/payments-component.svg \
  --deployment docs/diagrams/payments-deployment.svg \
  --sequence docs/diagrams/payments-sequence.svg
```

Flat mode behavior:
- `--context`, `--container`, and `--component` are required.
- `--landscape`, `--deployment`, and `--sequence` are optional.
- `README.md` is read by default and the first meaningful paragraph is shown at
  the top as a short system description. Override with `--readme <path>`.
- The explorer auto-renders in compact mode for small repos.

### Mode 2: Complex Repo Mode (hierarchical manifest)

Use a JSON manifest when the repo contains multiple systems, multiple
containers, and multiple component diagrams.

```bash
scripts/build_explorer.sh \
  --manifest docs/diagrams/c4-explorer.json \
  --out docs/diagrams/platform-c4-explorer.html
```

You can override manifest metadata at runtime:

```bash
scripts/build_explorer.sh \
  --manifest docs/diagrams/c4-explorer.json \
  --out docs/diagrams/platform-c4-explorer.html \
  --title "Platform C4 Explorer" \
  --readme README.md
```

Manifest mode behavior:
- `--manifest` and the flat diagram flags are mutually exclusive.
- Hierarchy comes from the manifest (Landscape -> Systems -> Containers ->
  Components).
- `readme` and diagram paths in the manifest are resolved relative to the
  manifest file location by default. CLI overrides like `--readme` are resolved
  relative to the current working directory.
- Context and Container diagrams are required per system.
- Component diagrams are required for each declared component entry.
- Missing optional Landscape/Deployment/Sequence diagrams are skipped with a
  warning.
- The explorer auto-renders tree navigation for complex repos and compact mode
  for smaller manifests.

### Manifest Schema (JSON)

```json
{
  "title": "Payments Platform",
  "readme": "README.md",
  "landscape": "docs/diagrams/payments-landscape.svg",
  "systems": [
    {
      "id": "payments_core",
      "name": "Payments Core",
      "context": "docs/diagrams/payments-core-context.svg",
      "container": "docs/diagrams/payments-core-container.svg",
      "deployment": "docs/diagrams/payments-core-deployment.svg",
      "sequences": [
        {
          "id": "auth_flow",
          "name": "Payment Authorization Flow",
          "diagram": "docs/diagrams/payments-core-sequence-auth.svg"
        }
      ],
      "containers": [
        {
          "id": "api",
          "name": "Payments API",
          "components": [
            {
              "id": "api_components",
              "name": "API Components",
              "diagram": "docs/diagrams/payments-api-components.svg"
            }
          ]
        }
      ]
    }
  ]
}
```

Manifest checklist:
- Use stable IDs (`id`) for systems, containers, sequences, and components.
- Keep `readme` and diagram paths relative to the manifest file when possible.
- Declare only the component diagrams that add architectural value.
- Add multiple sequence diagrams only for important scenarios.

### Explorer UI behavior

- Header includes:
  - C4 intro paragraph and link to the C4 model
  - README-derived system summary paragraph
- Clicking a diagram opens it in a fullscreen viewer; close with Escape,
  backdrop click, or the close button.
- Prefer SVG inputs when available; use PNG otherwise.

### Smoke test workflow (C4 preload validation)

Use the built-in smoke test to catch regressions in the vendored C4 preload
bundle or render wrapper:

```bash
cd public/c4-diagrams
make smoke
```

This renders minimal diagrams for:
- context
- container
- component
- dynamic
- sequence
- deployment

The command fails if any render fails.

Optional layout heuristic helper:
- `scripts/check_layout_aspect.sh <svg>` warns when a diagram is suspiciously
  tall (e.g., top-down "string" layout instead of balanced 2D usage).
- `scripts/smoke_test.sh` runs this check automatically for context/container
  smoke outputs.
- Set `C4_LAYOUT_FAIL_ON_WARN=1` to make suspicious aspect ratios fail CI/smoke
  runs.


## C4-PlantUML

**C4-PlantUML** is a PlantUML-based library that lets you describe software
architecture using the C4 model (Context, Container, Component, Code) as
concise, text-based diagrams that are easy to version and automate.


### Basic Syntax

This is the syntax for a file `my-systems.puml`.

```plantuml
@startuml my-systems
' C4 macros are auto-loaded by scripts/render.sh

Person(user, "User", "A user of the system")
System(system, "My System", "Does something useful")

Rel(user, system, "Uses")
@enduml
```

### Include the library

Prefer the vendored local bundle. `scripts/render.sh` preloads
`assets/includes/C4/C4_All.puml` and sets `RELATIVE_INCLUDE` to the local bundle path,
so the full C4 macro stack is available without adding any include line in your
diagram:
- `C4_Context` (system landscape/context macros such as `Person`, `System`,
  `System_Ext`, `Rel`, `Rel_*`, `Lay_*`)
- `C4_Container`
- `C4_Component`
- `C4_Dynamic`
- `C4_Deployment`
- `C4_Sequence`

``` plantuml
' Preferred with this skill: no explicit include required.
' scripts/render.sh preloads the local vendored C4 bundle.

' Optional fallback if you do not use scripts/render.sh:
' !include https://raw.githubusercontent.com/plantuml-stdlib/C4-PlantUML/master/C4_Container.puml
```

## Troubleshooting C4 include/preload failures

Common symptoms:
- `Unknown keyword` / `Undefined procedure` for macros like `Person`, `System`,
  `Rel`, `Container`, `Component`, `RelIndex`, or `Deployment_Node`
- Diagram renders only when you add explicit `!include` lines

Checks:
- Confirm you are rendering via `scripts/render.sh` (not raw `plantuml`)
- Confirm `assets/includes/C4/C4_All.puml` includes the full C4 set (Context,
  Container, Component, Dynamic, Deployment, Sequence)
- Confirm `RELATIVE_INCLUDE` points at the vendored `assets/includes/C4`
  directory (the wrapper injects this automatically)
- Run `make smoke` in `public/c4-diagrams` to validate preloading across all C4
  levels
- Run `scripts/check_layout_aspect.sh <diagram.svg>` if a context/container
  diagram looks suspiciously tall or linear

If `scripts/render.sh` fails, it may print a hint about checking
`C4_All.puml` contents and the injected `RELATIVE_INCLUDE` path.

### Layout orientation

To control the layout orientation, place these **before** element declarations:

``` plantuml
' Preferred: keeps Rel_* meaning stable (Up is up, Right is right)
LAYOUT_LANDSCAPE()

left to right direction     ' or: top to bottom direction

' Legacy, do not use: rotates directions (Up becomes Left, etc.)
' LAYOUT_LEFT_RIGHT()
```

### Control relationship direction (edge routing)

Use directional relationship macros to force relative placement:

``` plantuml
Rel_U(a, b, "Up")      ' b above a
Rel_D(a, c, "Down")    ' c below a
Rel_L(a, d, "Left")    ' d left of a
Rel_R(a, e, "Right")   ' e right of a
BiRel_R(x, y, "Bidirectional to the right")
```

### Arrange elements without relationships

When two elements have no edge but their relative position matters, use `Lay_*`
macros:

``` plantuml
Lay_U(a, b)
Lay_R(a, c)
Lay_D(a, d)
Lay_L(a, e)

' Increase spacing (esp. with floating legends):
Lay_Distance(a, LEGEND(), 2)
```

### Practical layout tips

* Declare nodes in a logical order; PlantUML uses declaration order as a hint. If
  auto-layout fights you, switch to `Rel_*`/`Lay_*`.
* Inside boundaries, you can still use `Rel_*` and `Lay_*` to stabilize placement.
* Be careful about auto vs manual layout and element ordering: Even though you
  can force layouts with `Lay_*()`, you should remember that PlantUML (and
  C4-PlantUML) are fundamentally automatic layout systems. For large diagrams,
  heavy manual placement may backfire. The order in which you declare elements
*and* their relationships influences layout. [crashedmind.github.io](https://crashedmind.github.io/PlantUMLHitchhikersGuide/layout/layout.html)
* If edges still cross awkwardly, nudge with `Lay_*` or reorder declarations.
* Make sure you don't have overlapping text labels
* If layout goes weird, try:
  * Re-ordering your element declarations
  * Using hidden/"invisible" relationships to enforce grouping or ranking
  * Minimizing forced placements only where really needed

### Balanced 2D template (default pattern for Context/Container diagrams)

When a Context or Container diagram starts rendering as a vertical chain, use a
"hub-and-spoke" layout pattern around the primary system/container instead of a
linear `Rel(...)` chain.

Template (adapt names/macros to Context vs Container level):

```plantuml
@startuml
' C4 macros are auto-loaded by scripts/render.sh
LAYOUT_LANDSCAPE()
left to right direction

' Place the primary system/container near the center
Person(user, "Primary User", "Main actor")
Person(admin, "Admin", "Operations/maintenance")
System(system, "My System", "System in scope")
System_Ext(ext_api, "External API", "Upstream/downstream integration")
System_Ext(ext_queue, "Message Broker", "Async messaging")
System_Ext(ext_store, "Data Store", "Persistence / files")

' Anchor positions (use directional relations for placement + semantics)
Rel_R(user, system, "Uses")
Rel_D(admin, system, "Administers")
Rel_R(system, ext_api, "Calls")
Rel_D(system, ext_queue, "Publishes/Consumes")
Rel_L(ext_store, system, "Stores state for")

' Optional peer spacing hints to use 2D space better
Lay_U(user, admin)
Lay_R(ext_api, ext_queue)
Lay_D(ext_queue, ext_store)
@enduml
```

Practical guidance:
- Put the system-in-scope near the center of the diagram.
- Group humans/actors on one side and external systems on the opposite side.
- Use `Rel_*` for the primary placement hints, then `Lay_*` only to nudge.
- If a diagram is still too tall, reduce crossings by reordering declarations
  before adding more layout constraints.

### Use sprites/icons and hyperlinks to enrich elements

You don’t have to stick to plain boxes. C4-PlantUML supports `$sprite` and
`$link` (and even `$descr`) properties for elements, making your diagrams
richer and more interactive.  For example:

This enhances readability (icon for the type) and traceability (link to docs).

**Tip:** Use icons sparingly — too many visual flourishes can distract from the
architecture story.

### Tag elements and relationships for legends / filtering

You can add tags to elements and relationships (via macros like `AddElementTag`,
`AddRelTag`) so you can group or highlight things (versions, deprecated, backup, etc).
Then you can use `SHOW_LEGEND()` or `LAYOUT_WITH_LEGEND()` and the legend will show the
meaning of those tags.

**Tip:** Use this when you need to communicate extra metadata (e.g., “v1.0”, “deprecated”,
“beta”) without cluttering the main diagram.

## Open Questions

- Ask whether to create diagrams in `$REPO_ROOT/docs/diagrams` (default) of the
  user wants to have a `./diagrams/` directly folder next to some other files.
