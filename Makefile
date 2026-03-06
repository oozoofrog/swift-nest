HARNESS ?= ./harness
CONFIG ?= config/project.yaml
TARGET ?=
PROFILE ?= intermediate

install-harness:
	@test -n "$(TARGET)" || (echo "TARGET is required"; exit 1)
	$(HARNESS) install --target "$(TARGET)"

list-skills:
	$(HARNESS) list-skills

list-profiles:
	$(HARNESS) list-profiles

init:
	$(HARNESS) init --config $(CONFIG)

context:
	$(HARNESS) render-context

upgrade:
	$(HARNESS) upgrade --to $(PROFILE)
