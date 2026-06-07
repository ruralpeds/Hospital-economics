#!/bin/bash
# ============================================================================
# Overnight Build Script for Rural Hospital Economics
# ============================================================================

LOG_FILE="OVERNIGHT_BUILD.log"
# Clear log if it exists
> "$LOG_FILE"

# Function to log and print
log() {
    echo "$1" | tee -a "$LOG_FILE"
}

log "🚀 Starting Overnight Build"
log "Started at: $(date)"
log "----------------------------------------------------------------------------"

# 1. Dependency Management
log "📦 [1/5] Installing and Precompiling Dependencies..."
julia --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.precompile()' >> "$LOG_FILE" 2>&1
if [ $? -eq 0 ]; then log "✓ Success"; else log "✗ Failed"; fi

# 2. Linting and Code Quality
log "🔍 [2/5] Running Code Quality Checks (Aqua.jl)..."
julia --project=. -e 'using Aqua, RuralHospitalSim; Aqua.test_all(RuralHospitalSim; ambiguities=false)' >> "$LOG_FILE" 2>&1
if [ $? -eq 0 ]; then log "✓ Success"; else log "✗ Failed"; fi

# 3. Unit and Integration Tests
log "🧪 [3/5] Running Full Test Suite (This may take some time)..."
julia --project=. -e 'using Pkg; Pkg.test()' >> "$LOG_FILE" 2>&1
if [ $? -eq 0 ]; then log "✓ Success"; else log "✗ Failed"; fi

# 4. Performance Benchmarks
log "📈 [4/5] Running Performance Benchmarks..."
julia --project=. scripts/benchmark.jl >> "$LOG_FILE" 2>&1
if [ $? -eq 0 ]; then log "✓ Success"; else log "✗ Failed"; fi

# 5. Data Integrity
log "💾 [5/5] Verifying Sample Data..."
julia --project=. scripts/seed_data.jl >> "$LOG_FILE" 2>&1
if [ $? -eq 0 ]; then log "✓ Success"; else log "✗ Failed"; fi

log "----------------------------------------------------------------------------"
log "✅ Overnight Build Process Finished"
log "Finished at: $(date)"
log "Detailed log saved to: $LOG_FILE"
