## Resilens public agent skills

[Agent Skills](https://agentskills.io) are a lightweight, open format for extending AI agent capabilities with specialized knowledge and workflows.

This repository contains the public subset of the Resilens shared skills library.

### How To Use
```bash
# validate all public skills
make validate

# install all public skills to the default location (~/.agents/skills)
make install-skills

# install to a custom destination used by your agent runtime
make install-skills SKILLS_DIR=/path/to/skills
```

You can skip specific skills during install or validation:
```bash
make install-skills SKIP="c4-diagrams"
```

### Structure
- Each skill lives in its own directory and includes a `SKILL.md`.

### Skills
Current public skills:

| Skill | Description | Author | Version |
| --- | --- | --- | --- |
| `c4-diagrams` | Use for architectural analysis and documentation; create C4 PlantUML diagrams with clear actors, system boundaries, containers, components, and relationships. | Stephan | 0.1 |
