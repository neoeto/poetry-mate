.PHONY: install test info clean

VENV := .venv
PYTHON_BIN ?= python3

$(VENV)/bin/python:
	$(PYTHON_BIN) -m venv $(VENV)

install: $(VENV)/bin/python
	$(VENV)/bin/pip install --upgrade pip
	$(VENV)/bin/pip install -e ".[dev]"

test:
	$(VENV)/bin/pytest -q

info:
	$(VENV)/bin/python -m poetry_etl info

clean:
	rm -rf $(VENV) build dist *.egg-info src/*.egg-info
	find . -type d -name "__pycache__" -exec rm -rf {} +
