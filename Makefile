SWIFTNEST ?= ./swiftnest
HARNESS ?= $(SWIFTNEST)
CONFIG ?= config/project.yaml
TARGET ?=
PROFILE ?= intermediate

install-swiftnest:
	@test -n "$(TARGET)" || (echo "TARGET is required"; exit 1)
	$(SWIFTNEST) install --target "$(TARGET)"

install-harness:
	$(MAKE) install-swiftnest TARGET="$(TARGET)" SWIFTNEST="$(SWIFTNEST)"

list-skills:
	$(SWIFTNEST) list-skills

list-profiles:
	$(SWIFTNEST) list-profiles

init:
	$(SWIFTNEST) init --config $(CONFIG)

context:
	$(SWIFTNEST) render-context

upgrade:
	$(SWIFTNEST) upgrade --to $(PROFILE)
