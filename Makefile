.PHONY: run test lint format install docker-build docker-run help

help:
	@echo "RailConnect Makefile Commands"
	@echo "=============================="
	@echo "make run          - Run the Flask development server"
	@echo "make test         - Run pytest with coverage"
	@echo "make lint         - Run flake8 linter"
	@echo "make format       - Format code with black"
	@echo "make install      - Install all dependencies"
	@echo "make docker-build - Build Docker image"
	@echo "make docker-run   - Run Docker container"

run:
	python run.py

test:
	pytest tests/ -v --cov=app --cov-report=term-missing

lint:
	flake8 app/ --max-line-length=100

format:
	black app/ tests/

install:
	pip install -r requirements.txt -r requirements-dev.txt

docker-build:
	docker build -t railconnect:local .

docker-run:
	docker run -p 5003:5000 -e POD_NAME=local-docker railconnect:local
