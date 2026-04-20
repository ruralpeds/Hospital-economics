#!/bin/bash

# ============================================================================
# Rural Hospital Economics Platform - Claude Code Agentic Build Starter
# HospitalFinanceToolbox.jl v0.2.0 Development
# 
# Usage: bash claude-code-start.sh
# ============================================================================

echo "🏥 Rural Hospital Economics Platform - Claude Code Bootstrap"
echo "================================================================"

# Configuration
PROJECT_DIR="${HOME}/HospitalFinanceToolbox.jl"
REPO="https://github.com/timothyhartzog/Hospital-economics.git"

# Step 1: Clone or update repo
echo "📦 Setting up repository..."
if [ -d "$PROJECT_DIR" ]; then
    cd "$PROJECT_DIR"
    git pull origin main 2>/dev/null || echo "  (already up to date)"
else
    git clone "$REPO" "$PROJECT_DIR"
    cd "$PROJECT_DIR"
fi
echo "✓ Repository ready at $PROJECT_DIR"

# Step 2: Create .claude-code directory with instructions
echo "📋 Creating Claude Code configuration..."
mkdir -p .claude-code

# BUILD_PLAN.md
cat > .claude-code/BUILD_PLAN.md << 'EOF'
# HospitalFinanceToolbox.jl v0.2.0 — Build Plan

## Mission
Build service line profitability analysis module for rural hospitals.

## What to Build

### 1. ServiceLineTypes.jl
Location: `src/episode/ServiceLineTypes.jl`

Types needed:
- `ServiceLine` - represents one service line with financials
- `ServiceLineAnalysisResult` - results from analysis
- Helper types for cost allocation methods

### 2. ServiceLineCostAllocation.jl  
Location: `src/episode/ServiceLineCostAllocation.jl`

Functions needed:
- `allocate_direct_costs()` - Cost allocation by department
- `allocate_indirect_costs()` - Three methods (proportional, activity-based, step-down)
- `calculate_margins()` - Profitability metrics

### 3. ServiceLineMetrics.jl
Location: `src/episode/ServiceLineMetrics.jl`

Functions:
- `calculate_margin()` - % margin by service
- `calculate_contribution_margin()` - Contribution to overhead
- `efficiency_metrics()` - Volume and cost per unit

### 4. Benchmarking.jl
Location: `src/episode/Benchmarking.jl`

Functions:
- `load_benchmarks()` - Load rural hospital benchmark data
- `benchmark_compare()` - Compare hospital to benchmarks
- `identify_outliers()` - Find high/low cost services

### 5. Example & Tests
- `examples/05_service_line_profitability.jl` - Real hospital analysis
- `test/test_service_line_*.jl` - Comprehensive tests

## Success Criteria
- Rural hospital CFO can run analysis in <2 hours
- >90% test coverage
- All tests passing
- Clear output and recommendations
- Real hospital example works
EOF

# IMMEDIATE_TASKS.md
cat > .claude-code/IMMEDIATE_TASKS.md << 'EOF'
# Tasks for Claude Code Agentic Build

## Week 1: Core Module
- [ ] Create ServiceLineTypes.jl with all required structs
- [ ] Write unit tests for types
- [ ] Implement ServiceLineCostAllocation.jl
- [ ] Test all cost allocation methods

## Week 2: Metrics & Benchmarking
- [ ] Create ServiceLineMetrics.jl
- [ ] Implement Benchmarking.jl
- [ ] Write tests for metrics and benchmarking
- [ ] Validate calculations

## Week 3: Examples & Integration
- [ ] Create comprehensive example
- [ ] Load real hospital financial data
- [ ] Test on multiple scenarios
- [ ] Integration with existing code

## Week 4: Polish & Documentation
- [ ] Complete test coverage (>90%)
- [ ] Write user guide (docs/SERVICE_LINE_GUIDE.md)
- [ ] Add docstrings to all functions
- [ ] Generate sample outputs

## Key Files to Reference
- src/health_economics/QALY.jl (design patterns)
- src/health_economics/ICER.jl (calculation patterns)
- src/episode/Episode.jl (type structure)
- test/runtests.jl (testing patterns)
EOF

# CLAUDE_CODE_INSTRUCTIONS.md
cat > .claude-code/CLAUDE_CODE_INSTRUCTIONS.md << 'EOF'
# How to Use Claude Code for This Build

## Start Here
1. Read BUILD_PLAN.md (what to build)
2. Review IMMEDIATE_TASKS.md (task list)
3. Read existing code: src/health_economics/QALY.jl and ICER.jl
4. Start with ServiceLineTypes.jl

## Development Rules
✅ DO:
- Write tests immediately after each function
- Reference BUILD_PLAN.md for exact specs
- Review similar code (QALY.jl, ICER.jl) for patterns
- Commit small, focused changes
- Include docstrings with rural hospital context

❌ DON'T:
- Write big chunks without testing
- Forget documentation
- Commit failing code
- Ignore test failures

## Commands
```bash
cd ~/HospitalFinanceToolbox.jl
julia --project                    # Start Julia
julia --project -e 'using Pkg; Pkg.test()'  # Run tests
```

## Success = v0.2.0 Complete When
- All Priority 1 tasks done
- >90% test coverage
- All tests passing
- Real hospital example runs
- Documentation complete
EOF

# AGENTIC_START.md
cat > .claude-code/AGENTIC_START.md << 'EOF'
# Claude Code Agentic Build - START HERE

## Quick Start
```bash
cd ~/HospitalFinanceToolbox.jl
julia --project
```

Then in Julia:
```julia
include("src/HospitalFinanceToolbox.jl")
# Start building ServiceLineTypes.jl
```

## What You're Building
Service Line Profitability Analysis for Rural Hospitals

**User Goal:** Rural hospital CFO asks "Which services make money?"

**Your Goal:** Build module to answer that in <2 hours

## First Task: ServiceLineTypes.jl

Create: `src/episode/ServiceLineTypes.jl`

Define these structs:
```julia
struct ServiceLine
    id::String
    name::String
    department::String
    drg_codes::Vector{String}
    volume::Int
    revenue::Float64
    direct_cost::Float64
    allocated_indirect_cost::Float64
end

struct ServiceLineAnalysisResult
    service_lines::Vector{ServiceLine}
    total_margin::Float64
    margin_by_service::Dict{String, Float64}
    cost_drivers::Dict{String, Float64}
    recommendations::Vector{String}
end
```

## Then: Write Tests
Create: `test/test_service_line_types.jl`

Test:
- Creating ServiceLine instances
- Validating financial data
- Calculating basic metrics

## Then: Cost Allocation
Create: `src/episode/ServiceLineCostAllocation.jl`

Implement:
- Direct cost allocation
- Indirect cost allocation (3 methods)
- Margin calculations

## Reference Code
Read these files to understand patterns:
1. src/health_economics/QALY.jl - How to structure calculations
2. src/episode/Episode.jl - How to organize types
3. test/runtests.jl - How to test

## Commit Early, Commit Often
```bash
git add src/episode/ServiceLineTypes.jl test/test_service_line_types.jl
git commit -m "feat: add ServiceLine types and basic tests"
```

## You Got This!
- Clear goal: Service line profitability analysis
- Clear specs: BUILD_PLAN.md
- Clear tasks: IMMEDIATE_TASKS.md
- Clear patterns: Existing code
- Clear support: These instructions

Let's build something that helps rural hospitals! 🚀
EOF

echo "✓ Claude Code configuration created"

# Step 3: Create dev environment script
cat > dev_environment.sh << 'EOF'
#!/bin/bash
# Development environment setup

export JULIA_LOAD_PATH="${PWD}/src:@"
export JULIA_DEPOT_PATH="${HOME}/.julia"

alias jl="julia --project"
alias jl-test="julia --project -e 'using Pkg; Pkg.test()'"
alias jl-dev="julia --project -i -e 'using Pkg; Pkg.activate(\".\")'"

echo "✓ Development environment ready"
echo "  jl = Julia REPL"
echo "  jl-test = Run tests"
echo "  jl-dev = Interactive development"
EOF

chmod +x dev_environment.sh
echo "✓ Development environment script created"

# Step 4: Final instructions
echo ""
echo "================================================================"
echo "🎯 Setup Complete - Ready for Claude Code Agentic Build!"
echo "================================================================"
echo ""
echo "📁 Project Location: $PROJECT_DIR"
echo ""
echo "📚 Read These Files (in order):"
echo "   1. .claude-code/AGENTIC_START.md     ← Start here"
echo "   2. .claude-code/BUILD_PLAN.md        ← Detailed specs"
echo "   3. .claude-code/IMMEDIATE_TASKS.md   ← Task list"
echo ""
echo "🚀 Quick Commands:"
echo "   cd $PROJECT_DIR"
echo "   source dev_environment.sh"
echo "   jl              # Start Julia"
echo "   jl-test         # Run tests"
echo ""
echo "🎓 Reference Code:"
echo "   src/health_economics/QALY.jl (read for patterns)"
echo "   src/health_economics/ICER.jl (read for patterns)"
echo "   src/episode/Episode.jl (type structure example)"
echo ""
echo "✨ Ready to Build Service Line Profitability Analysis"
echo "   Timeline: 4 weeks to production (v0.2.0)"
echo "   Target: Rural hospital CFO can use in <2 hours"
echo ""
