.PHONY: help validate install-skills

# Default install destinations for shared agent skill homes.
# Override with SKILLS_DIR to install to one directory only.
DEFAULT_SKILLS_DIRS := $(HOME)/.agents/skills $(HOME)/.codex/skills $(HOME)/.claude/skills
SKILLS_DIR ?=
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
		uvx --from skills-ref agentskills validate "$$skill"; \
	done

install-skills: $(TARGET_SKILLS:%=%/SKILL.md) ## Install public skills into default shared homes, or SKILLS_DIR if set
	@if [ -z "$(TARGET_SKILLS)" ]; then \
		printf "No skills found (expected */SKILL.md).\n"; \
		exit 1; \
	fi
	@set -- $(DEFAULT_SKILLS_DIRS); \
	if [ -n "$(SKILLS_DIR)" ]; then \
		set -- "$(SKILLS_DIR)"; \
	fi; \
	for skills_dir in "$$@"; do \
		mkdir -p "$$skills_dir"; \
		for skill in $(TARGET_SKILLS); do \
			name=$$(basename "$$skill"); \
			printf "Install skill %s (from %s) -> %s\n" "$$name" "$$skill" "$$skills_dir"; \
			rm -rf "$$skills_dir/$$name"; \
			cp -R "$$skill" "$$skills_dir/$$name"; \
		done; \
		display_dir="$$skills_dir"; \
		case "$$display_dir" in \
			"$(HOME)/.agents/skills") display_dir="~/.agents/skills" ;; \
			"$(HOME)/.codex/skills") display_dir="~/.codex/skills" ;; \
			"$(HOME)/.claude/skills") display_dir="~/.claude/skills" ;; \
		esac; \
		index_file="$$skills_dir/INDEX.md"; \
		printf "# Installed skills\n\n" > "$$index_file"; \
		for skill in $(TARGET_SKILLS); do \
			name=$$(basename "$$skill"); \
			printf "@%s/%s/SKILL.md\n" "$$display_dir" "$$name" >> "$$index_file"; \
		done; \
		printf "Wrote index %s\n" "$$index_file"; \
	done
