PYTHON ?= python3
CONFIG ?= my-project.yaml

list-skills:
	$(PYTHON) scripts/harness.py list-skills

list-profiles:
	$(PYTHON) scripts/harness.py list-profiles

init:
	$(PYTHON) scripts/harness.py init --config $(CONFIG)

context:
	$(PYTHON) scripts/harness.py render-context
