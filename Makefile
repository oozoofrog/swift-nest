PYTHON ?= python3
CONFIG ?= my-project.yaml
XCODE_APP ?= /Applications/Xcode.app

list-skills:
	$(PYTHON) scripts/harness.py list-skills

list-profiles:
	$(PYTHON) scripts/harness.py list-profiles

init:
	$(PYTHON) scripts/harness.py init --config $(CONFIG)

context:
	$(PYTHON) scripts/harness.py render-context

extract-xcode-docs:
	$(PYTHON) scripts/extract_xcode_reference_docs.py --xcode-app "$(XCODE_APP)"
