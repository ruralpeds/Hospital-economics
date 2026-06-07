#!/bin/bash

# ============================================================================
# Autonomous Overnight Readiness Build
# Follows the Verification section of PRODUCTION_READINESS_PLAN.md
# ============================================================================

set -e

LOG_FILE="AUTONOMOUS_BUILD.log"
# Clear log if it exists
> "$LOG_FILE"

# Function to log and print
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log "🚀 Starting Autonomous Overnight Readiness Build"
log "----------------------------------------------------------------------------"

# 1. Julia Test Suite
log "🧪 [1/6] Running Full Julia Test Suite..."
julia --project=. -e 'using Pkg; Pkg.Registry.add("General"); Pkg.instantiate(); Pkg.test()' >> "$LOG_FILE" 2>&1
if [ $? -eq 0 ]; then log "✓ Julia Tests Passed"; else log "✗ Julia Tests Failed"; fi

# 2. Docker Stack Health
log "🐳 [2/6] Verifying Docker Stack (Compose + Healthz)..."
if command -v docker-compose &> /dev/null || docker compose version &> /dev/null; then
    docker compose up -d >> "$LOG_FILE" 2>&1
    log "Waiting for stack to be ready..."
    # Simple retry loop for /readyz
    max_retries=10
    count=0
    until $(curl --output /dev/null --silent --head --fail http://localhost:8080/readyz); do
        printf '.'
        sleep 5
        count=$((count+1))
        if [ $count -ge $max_retries ]; then
            log "✗ Stack /readyz timeout"
            break
        fi
    done
    if [ $count -lt $max_retries ]; then log "✓ Stack Ready"; fi
    docker compose down >> "$LOG_FILE" 2>&1
else
    log "⚠️ Docker not available inside container"
fi

# 3. E2E Tests (Playwright)
log "🎭 [3/6] Running E2E Tests (Playwright)..."
if [ -d "e2e" ]; then
    npm install >> "$LOG_FILE" 2>&1
    npx playwright install-deps >> "$LOG_FILE" 2>&1
    npx playwright test >> "$LOG_FILE" 2>&1
    if [ $? -eq 0 ]; then log "✓ E2E Tests Passed"; else log "✗ E2E Tests Failed"; fi
else
    log "ℹ️ No e2e directory found"
fi

# 4. Infrastructure-as-Code Validation
log "🏗️ [4/6] Validating Terraform and Helm..."
if [ -d "terraform" ]; then
    terraform init -backend=false >> "$LOG_FILE" 2>&1
    terraform validate >> "$LOG_FILE" 2>&1
    if [ $? -eq 0 ]; then log "✓ Terraform Validated"; else log "✗ Terraform Validation Failed"; fi
fi
if [ -d "helm" ]; then
    helm lint helm/ >> "$LOG_FILE" 2>&1
    if [ $? -eq 0 ]; then log "✓ Helm Linted"; else log "✗ Helm Lint Failed"; fi
fi

# 5. Security & Hygiene
log "🔒 [5/6] Running Security Scans (Trivy + Aqua)..."
trivy fs . >> "$LOG_FILE" 2>&1
if [ $? -eq 0 ]; then log "✓ Security Scan Finished"; else log "✗ Security Scan Failed"; fi

julia --project=. -e 'using Pkg; Pkg.add("Aqua"); using Aqua; Aqua.test_all(JuliaSim; ambiguities=false)' >> "$LOG_FILE" 2>&1
if [ $? -eq 0 ]; then log "✓ Aqua Hygiene Passed"; else log "✗ Aqua Hygiene Failed"; fi

# 6. Report Generation
log "📊 [6/6] Generating Readiness Report..."
echo "# Production Readiness Report - $(date)" > READINESS_REPORT.md
echo "## Summary" >> READINESS_REPORT.md
tail -n 20 "$LOG_FILE" >> READINESS_REPORT.md

log "----------------------------------------------------------------------------"
log "✅ Autonomous Build Process Finished"
log "Detailed log saved to: $LOG_FILE"
log "Summary report saved to: READINESS_REPORT.md"
