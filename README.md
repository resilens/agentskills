## Resilens public agent skills

[Agent Skills](https://agentskills.io) are a lightweight, open format for extending AI agent capabilities with specialized knowledge and workflows.

This repository contains the public subset of the Resilens shared skills library.

### Prerequisites
- Install `uv`: <https://docs.astral.sh/uv/>
- `make validate` requires `uvx`.
- `make install-skills` does not require `uv`.

### How To Use
```bash
# validate all public skills
make validate

# install all public skills to the default location (~/.agents/skills)
make install-skills

# install to a custom destination used by your agent runtime
make install-skills SKILLS_DIR=/path/to/skills
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
