#!/bin/bash
set -e

PROJECT_DIR="/Users/thartzog/HospitalFinanceToolbox.jl"
STAGE="${1:-current}"

if [ ! -d "$PROJECT_DIR" ]; then
    echo "❌ Project directory not found: $PROJECT_DIR"
    exit 1
fi

cd "$PROJECT_DIR"

echo "🏗️  Building HospitalFinanceToolbox.jl - Stage: $STAGE"
echo "======================================================"

# Function to run Julia code
run_julia() {
    local code="$1"
    julia --project -e "$code"
}

# Check if Project.toml exists
if [ ! -f "Project.toml" ]; then
    echo "❌ No Project.toml found. Run bootstrap.sh first."
    exit 1
fi

# Function to build current week's tasks (Week 1)
build_current() {
    echo ""
    echo "📋 Building CURRENT (Week 1) Tasks..."
    echo "   • ServiceLineTypes.jl"
    echo "   • ServiceLineCostAllocation.jl"
    echo "   • Unit tests"
    echo ""

    # Run Julia and execute the build script
    run_julia 'include("scripts/build_week1.jl")'

    echo "✓ Week 1 build complete"
}

# Function to run all tests
run_tests() {
    echo ""
    echo "🧪 Running all tests..."
    julia --project -e 'using Pkg; Pkg.test()'
    echo "✓ All tests passed"
}

# Function to build week 2
build_week2() {
    echo ""
    echo "📋 Building Week 2 Tasks..."
    echo "   • ServiceLineMetrics.jl"
    echo "   • Benchmarking.jl"
    echo "   • Metrics tests"
    echo ""

    run_julia 'include("scripts/build_week2.jl")'

    echo "✓ Week 2 build complete"
}

# Function to build week 3
build_week3() {
    echo ""
    echo "📋 Building Week 3 Tasks..."
    echo "   • Examples"
    echo "   • Integration tests"
    echo ""

    run_julia 'include("scripts/build_week3.jl")'

    echo "✓ Week 3 build complete"
}

# Function to build week 4 (polish)
build_week4() {
    echo ""
    echo "📋 Building Week 4 (Polish)..."
    echo "   • Documentation"
    echo "   • Final tests"
    echo ""

    run_julia 'include("scripts/build_week4.jl")'

    echo "✓ Week 4 complete"
}

# Function to show status
show_status() {
    echo ""
    echo "📊 Build Status:"
    echo ""

    # Check which files exist
    [ -f "src/episode/ServiceLineTypes.jl" ] && echo "✓ ServiceLineTypes.jl" || echo "✗ ServiceLineTypes.jl"
    [ -f "src/episode/ServiceLineCostAllocation.jl" ] && echo "✓ ServiceLineCostAllocation.jl" || echo "✗ ServiceLineCostAllocation.jl"
    [ -f "src/episode/ServiceLineMetrics.jl" ] && echo "✓ ServiceLineMetrics.jl" || echo "✗ ServiceLineMetrics.jl"
    [ -f "src/episode/Benchmarking.jl" ] && echo "✓ Benchmarking.jl" || echo "✗ Benchmarking.jl"
    [ -f "examples/05_service_line_profitability.jl" ] && echo "✓ Example (Week 3)" || echo "✗ Example (Week 3)"
    [ -f "docs/SERVICE_LINE_GUIDE.md" ] && echo "✓ Documentation (Week 4)" || echo "✗ Documentation (Week 4)"

    echo ""
}

# Route to correct build stage
case "$STAGE" in
    current|week1)
        build_current
        show_status
        ;;
    week2)
        build_week2
        show_status
        ;;
    week3)
        build_week3
        show_status
        ;;
    week4|polish)
        build_week4
        show_status
        ;;
    test)
        run_tests
        ;;
    status)
        show_status
        ;;
    all)
        build_current
        run_tests
        build_week2
        run_tests
        build_week3
        run_tests
        build_week4
        run_tests
        show_status
        ;;
    *)
        echo "❌ Unknown stage: $STAGE"
        echo ""
        echo "Usage: ./build.sh [stage]"
        echo ""
        echo "Available stages:"
        echo "  current, week1  - Build Week 1 core module"
        echo "  week2           - Build Week 2 metrics & benchmarking"
        echo "  week3           - Build Week 3 examples"
        echo "  week4, polish   - Build Week 4 documentation"
        echo "  test            - Run all tests"
        echo "  status          - Show build status"
        echo "  all             - Build everything"
        echo ""
        exit 1
        ;;
esac

echo ""
echo "✨ Build stage '$STAGE' complete!"
echo ""
echo "Next steps:"
echo "  • ./build.sh test     - Run tests"
echo "  • ./build.sh status   - Check progress"
echo "  • jl                  - Start Julia REPL"
