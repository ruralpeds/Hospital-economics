#!/bin/bash
set -e

echo "🚀 Bootstrap HospitalFinanceToolbox.jl"
echo "======================================"

PROJECT_DIR="/Users/thartzog/HospitalFinanceToolbox.jl"

if [ ! -d "$PROJECT_DIR" ]; then
    echo "❌ Project directory not found: $PROJECT_DIR"
    exit 1
fi

cd "$PROJECT_DIR"
echo "✓ Working directory: $(pwd)"

# Check Julia is installed
if ! command -v julia &> /dev/null; then
    echo "❌ Julia not found. Please install Julia first."
    exit 1
fi

echo "✓ Julia version: $(julia --version)"

# Instantiate Julia project dependencies
echo ""
echo "📦 Installing Julia dependencies..."
julia --project -e 'using Pkg; Pkg.instantiate()'
echo "✓ Dependencies installed"

# Precompile the package for faster startup
echo ""
echo "⚙️  Precompiling package..."
julia --project -e 'using Pkg; Pkg.precompile()' || true
echo "✓ Precompilation complete"

# Create necessary directories
echo ""
echo "📁 Creating directories..."
mkdir -p src/episode
mkdir -p test
mkdir -p examples
mkdir -p docs
echo "✓ Directories ready"

# Source the dev environment script
echo ""
echo "✨ Bootstrap complete!"
echo ""
echo "Next steps:"
echo "  1. source $PROJECT_DIR/dev_environment.sh"
echo "  2. ./build.sh current  (to build Week 1 tasks)"
echo "  3. jl  (to start Julia)"
