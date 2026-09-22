.DELETE_ON_ERROR:
SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c
.PHONY: help validate install-skills
SKILL_DIRS := $(patsubst %/SKILL.md,%,$(wildcard */SKILL.md))
TARGET_SKILLS := $(SKILL_DIRS)

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

install-skills: ## Copy all public skills to global Codex and Claude Code skill directories
	npx skills add . --skill '*' --agent codex --agent claude-code --global --copy --yes
