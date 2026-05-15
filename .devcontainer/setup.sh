#!/bin/bash
set -e

echo "--------------------------------------------------------"
echo "RuralPeds Hardened Julia Environment Setup"
echo "Started at: $(date)"
echo "User: $(whoami)"
echo "Path: $PATH"
echo "--------------------------------------------------------"

# 1. Ensure Julia is available
if ! command -v julia &> /dev/null; then
    echo "❌ Julia not found in PATH."
    echo "Checking /home/vscode/.juliaup/bin/julia..."
    if [ -f "/home/vscode/.juliaup/bin/julia" ]; then
        export PATH="/home/vscode/.juliaup/bin:$PATH"
        echo "✓ Julia found and added to PATH."
    else
        echo "❌ Julia binary not found at expected location."
        exit 1
    fi
fi

echo "✓ Julia version: $(julia --version)"

# 2. Setup Registries
echo "📦 Configuring Julia Registries..."
julia -e 'using Pkg; try Pkg.Registry.add("General"); catch e; println("Registry General already exists or failed to add: ", e); end'

# 3. Instantiate Project
echo "📦 Instantiating Project (this may take a few minutes)..."
if [ -f "Project.toml" ]; then
    julia --project=. -e 'using Pkg; Pkg.instantiate()'
    echo "✓ Project instantiated successfully."
else
    echo "⚠ Project.toml not found in current directory $(pwd)"
fi

# 4. Precompile
echo "⚙️ Precompiling (this may take a few minutes)..."
julia --project=. -e 'using Pkg; Pkg.precompile()'
echo "✓ Precompilation complete."

echo "--------------------------------------------------------"
echo "✓ RuralPeds Hardened Julia Environment Ready."
echo "Finished at: $(date)"
echo "--------------------------------------------------------"
