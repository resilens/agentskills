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
- `make install-skills` does not require `uv`.

## Mental model
- A skill is a directory containing `SKILL.md` plus optional scripts/assets.
- Install skills into the directory used by your runtime.

## Quickstart
From this public repo:

```bash
make validate
make install-skills
```

Defaults:
- `SKILLS_DIR` defaults to `~/.agents/skills`
- Override destination: `make install-skills SKILLS_DIR=/path/your-agent-uses`

## Runtime docs

### Codex
- Install local skills with `make install-skills`.
- Official docs:
  - [Codex CLI](https://developers.openai.com/codex/cli)
  - [Codex Skills](https://developers.openai.com/codex/skills)
  - [Codex configuration basics](https://developers.openai.com/codex/configuration/config-basics)

### Claude Code
- Install local skills with `make install-skills`.
- Official docs:
  - [Claude Code overview](https://docs.anthropic.com/en/docs/claude-code/overview)
  - [Claude Code settings](https://docs.anthropic.com/en/docs/claude-code/settings)
  - [Slash commands](https://docs.anthropic.com/en/docs/claude-code/slash-commands)
  - [Sub-agents](https://docs.anthropic.com/en/docs/claude-code/sub-agents)
  - [Common workflows](https://docs.anthropic.com/en/docs/claude-code/common-workflows)

## Troubleshooting
- Skill not found: verify installed destination path and that each skill directory contains `SKILL.md`.
- Updated skill not reflected: reinstall with `make install-skills` and restart/reload the runtime.
- Validation fails in restricted environments: rerun where `uvx --from skills-ref` can access package sources.
