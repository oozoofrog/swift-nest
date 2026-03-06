PYTHON ?= python3
CONFIG ?= config/project.yaml
TARGET ?=
PROFILE ?= intermediate

install-harness:
	@test -n "$(TARGET)" || (echo "TARGET is required"; exit 1)
	$(PYTHON) scripts/install_harness.py --target "$(TARGET)"

list-skills:
	$(PYTHON) scripts/harness.py list-skills

list-profiles:
	$(PYTHON) scripts/harness.py list-profiles

init:
	$(PYTHON) scripts/harness.py init --config $(CONFIG)

context:
	$(PYTHON) scripts/harness.py render-context

upgrade:
	$(PYTHON) scripts/harness.py upgrade --to $(PROFILE)
