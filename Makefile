.DELETE_ON_ERROR:
SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c
.PHONY: help validate check-skills-cli install-skills list-installed-skills uninstall-skills
SKILL_DIRS := $(patsubst %/SKILL.md,%,$(wildcard */SKILL.md))
TARGET_SKILLS := $(SKILL_DIRS)
SKILL_NAMES := $(notdir $(SKILL_DIRS))
SKILL_AGENTS ?= codex claude-code
SKILL_AGENT_ARGS := $(foreach agent,$(SKILL_AGENTS),--agent $(agent))
# npx --yes accepts the package download; skills --yes accepts skill changes.
SKILLS_CLI ?= npx --yes skills@1.9.0

help: ## output help for all targets
	@echo "Public Resilens skills"
	@echo
	@awk 'BEGIN {FS = ":.*?## "}; \
		/^###/ {printf "\n\033[1;33m%s\033[0m\n", substr($$0, 5)}; \
		/^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-18s\033[0m %s\n", $$1, $$2}' \
		$(MAKEFILE_LIST)

### Skill workflow
validate: $(TARGET_SKILLS:%=%/SKILL.md) ## Validate all public skills
	@if [ -z "$(TARGET_SKILLS)" ]; then \
		printf "No skills found (expected */SKILL.md).\n"; \
		exit 1; \
	fi
	@for skill in $(TARGET_SKILLS); do \
		uvx --from skills-ref agentskills validate "$$skill" || exit $$?; \
	done

check-skills-cli: ## Check that the skills CLI runner is available
	@command -v $(firstword $(SKILLS_CLI)) >/dev/null 2>&1 || { \
		printf "Missing %s; install Node.js/npm or override SKILLS_CLI.\n" "$(firstword $(SKILLS_CLI))"; \
		exit 1; \
	}

install-skills: check-skills-cli ## Copy all public skills to configured global agent skill directories
	$(SKILLS_CLI) add . --skill '*' $(SKILL_AGENT_ARGS) --global --copy --yes
	@for skill in $(SKILL_NAMES); do \
		for agent in $(SKILL_AGENTS); do \
			case "$$agent" in \
				codex) skills_dir="$(HOME)/.agents/skills" ;; \
				claude-code) skills_dir="$(HOME)/.claude/skills" ;; \
				*) continue ;; \
			esac; \
			if [ ! -f "$$skills_dir/$$skill/SKILL.md" ]; then \
				printf "Missing installed skill: %s/%s/SKILL.md\n" "$$skills_dir" "$$skill"; \
				exit 1; \
			fi; \
		done; \
	done

list-installed-skills: check-skills-cli ## List globally installed skills for configured agents
	$(SKILLS_CLI) list --global $(SKILL_AGENT_ARGS)

uninstall-skills: check-skills-cli ## Remove these public skills from configured global agent directories
	@if [ -z "$(SKILL_NAMES)" ]; then \
		printf "No skills found (expected */SKILL.md).\n"; \
		exit 1; \
	fi
	$(SKILLS_CLI) remove --global $(SKILL_AGENT_ARGS) --yes $(SKILL_NAMES)
