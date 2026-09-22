---
title: "Manual: Using these public skills with coding agents"
status: accepted
owner: Resilens team
last_reviewed: 2026-02-21
---

# Manual: Using these public skills with coding agents

This repository contains [Agent Skills](https://agentskills.io) intended for public reuse across coding agents.

## Prerequisites
- Install `uv`: <https://docs.astral.sh/uv/>
- `make validate` requires `uvx`.
- Install Node.js and npm to run `npx skills`.

## Mental model
- A skill is a directory containing `SKILL.md` plus optional scripts/assets.
- Install skills with the Vercel skills CLI.

## Quickstart
From this public repo:

```bash
make validate
make install-skills
```

The target delegates to `npx skills add . --skill '*' --agent codex --agent claude-code --global --copy --yes`.
Run that command directly to select skills, use project-local scope, or target a
different set of runtimes.

To remove only the skills defined in this checkout from the global Codex and Claude
Code directories, run:

```bash
make uninstall-skills
```

`install-skills`, `list-installed-skills`, and `uninstall-skills` default to Codex
and Claude Code. Override the target runtimes with `SKILL_AGENTS="codex cursor"`.

## Runtime docs

### Codex
- Install with `npx skills add resilens/agentskills --skill '*' --agent codex --global --copy --yes`.
- Official docs:
  - [Codex CLI](https://developers.openai.com/codex/cli)
  - [Codex Skills](https://developers.openai.com/codex/skills)
  - [Codex configuration basics](https://developers.openai.com/codex/configuration/config-basics)

### Claude Code
- Install with `npx skills add resilens/agentskills --skill '*' --agent claude-code --global --copy --yes`.
- Official docs:
  - [Claude Code overview](https://docs.anthropic.com/en/docs/claude-code/overview)
  - [Claude Code settings](https://docs.anthropic.com/en/docs/claude-code/settings)
  - [Slash commands](https://docs.anthropic.com/en/docs/claude-code/slash-commands)
  - [Sub-agents](https://docs.anthropic.com/en/docs/claude-code/sub-agents)
  - [Common workflows](https://docs.anthropic.com/en/docs/claude-code/common-workflows)

## Troubleshooting
- Skill not found: verify installed destination path and that each skill directory contains `SKILL.md`.
- Updated skill not reflected: rerun the `npx skills add` command and restart/reload the runtime.
- Validation fails in restricted environments: rerun where `uvx --from skills-ref` can access package sources.
