.PHONY: test run build docker-build docker-up docker-down clean deps lint

# Default Julia project flags
JULIA       := julia --project=.
JULIA_EXEC  := $(JULIA) --threads=auto

# ── Development ─────────────────────────────────────────────────────────────

deps:  ## Install/update dependencies
	$(JULIA) -e 'using Pkg; Pkg.instantiate(); Pkg.precompile()'

run:  ## Start the development server
	$(JULIA_EXEC) -e 'include("app/app.jl"); using .HospitalEconomicsApp; start()'

test:  ## Run the full test suite
	$(JULIA_EXEC) -e 'using Pkg; Pkg.test()'

lint:  ## Run Aqua.jl code quality checks
	$(JULIA_EXEC) -e 'using Aqua, RuralHospitalSim; Aqua.test_all(RuralHospitalSim; ambiguities=false)'

repl:  ## Open a Julia REPL with the project loaded
	$(JULIA_EXEC)

# ── Docker ──────────────────────────────────────────────────────────────────

docker-build:  ## Build the Docker image
	docker build -f docker/Dockerfile -t rhsim:latest .

docker-up:  ## Start the full Docker Compose stack
	cd docker && docker compose up -d --build

docker-down:  ## Stop the Docker Compose stack
	cd docker && docker compose down

docker-logs:  ## Tail Docker logs
	cd docker && docker compose logs -f app

# ── Cleanup ─────────────────────────────────────────────────────────────────

clean:  ## Remove generated files
	rm -rf data/exports/*.csv data/exports/*.json
	rm -rf *.log

# ── Help ────────────────────────────────────────────────────────────────────

help:  ## Show this help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'
