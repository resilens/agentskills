---
title: "Manual: Using these skills with coding agents"
status: accepted
owner: Resilens team
last_reviewed: 2026-02-21
---

# Manual: Using these skills with coding agents

This repository contains [Agent Skills](https://agentskills.io) for multiple coding agents, including Codex and Claude Code.

## Mental model
- A skill is a directory containing `SKILL.md` (plus optional scripts/assets).
- This repo stores source skills under `public/<skill>/` and `private/<skill>/`.
- Install skills into the directory used by your runtime.

## Quickstart
From this repo:

```bash
cd /path/to/team-skills
make validate
make install-skills
```

Defaults:
- `SKILLS_DIR` defaults to `~/.agents/skills`
- Override destination: `make install-skills SKILLS_DIR=/path/your-agent-uses`
- Sync root and public readmes from frontmatter: `make sync-readmes`

## Agent runtime docs

### Codex
- Install local skills with `make install-skills`.
- Ensure `SKILLS_DIR` points to where Codex discovers skills.
- Official docs:
  - [Codex CLI](https://developers.openai.com/codex/cli)
  - [Codex Skills](https://developers.openai.com/codex/skills)
  - [Codex configuration basics](https://developers.openai.com/codex/configuration/config-basics)

### Claude Code
- Install local skills with `make install-skills`.
- Point `SKILLS_DIR` to the directory used by your Claude Code workflow.
- Use project instructions and custom commands/sub-agents to invoke and standardize skill usage.
- Official docs:
  - [Claude Code overview](https://docs.anthropic.com/en/docs/claude-code/overview)
  - [Claude Code settings](https://docs.anthropic.com/en/docs/claude-code/settings)
  - [Slash commands](https://docs.anthropic.com/en/docs/claude-code/slash-commands)
  - [Sub-agents](https://docs.anthropic.com/en/docs/claude-code/sub-agents)
  - [Common workflows](https://docs.anthropic.com/en/docs/claude-code/common-workflows)

## Team sharing patterns
Choose one:

### Pattern A: User install (simplest)
Each teammate clones this repo and runs:

```bash
make install-skills
```

Pros: quick; works across agent runtimes.
Cons: each teammate must periodically update and reinstall.

### Pattern B: Repo-local skills (reproducible)
Mirror selected skill directories into the project repository where your agent runs.

Pros: project-scoped reproducibility.
Cons: extra sync step when skills evolve.

## Troubleshooting
- Skill not found: verify installed destination path and that each skill contains `SKILL.md`.
- Updated skill not reflected: reinstall with `make install-skills` and restart/reload the agent runtime.
- Public repo landing page is stale: run `make sync-readmes` to refresh `public/README.md` before publishing.
- Validation command fails in restricted environments: rerun where `uvx --from skills-ref` can access package sources.
