## Resilens public agent skills

[Agent Skills](https://agentskills.io) are a lightweight, open format for extending AI agent capabilities with specialized knowledge and workflows.

This repository contains the public subset of the Resilens shared skills library.

### Prerequisites
- Install `uv`: <https://docs.astral.sh/uv/>
- `make validate` requires `uvx`.
- Install Node.js and npm to run `npx skills`.

### How To Use
```bash
# validate all public skills
make validate

# copy all public skills to global Codex and Claude Code directories
make install-skills

# list globally installed skills for Codex and Claude Code
make list-installed-skills

# remove these public skills from global Codex and Claude Code directories
make uninstall-skills

# copy one public skill to Codex only
npx skills add . --skill c4-diagrams --agent codex --global --copy --yes
```

### Structure
- Each skill lives in its own directory and includes a `SKILL.md`.

### Documentation
- [Using skills with coding agents](docs/using-skills-with-agents.md)

### Skills
Current public skills:

| Skill | Description | Author | Version |
| --- | --- | --- | --- |
| `c4-diagrams` | Use for architectural analysis and documentation; create C4 PlantUML diagrams with clear actors, system boundaries, containers, components, and relationships. | Stephan | 0.1 |
