# ============================================================================
# Multi-stage Dockerfile for Rural Hospital Economics Simulator
# Chapter 35 — Production Deployment
# ============================================================================

# Stage 1: Build and precompile
# Base image is pulled from the AWS ECR public mirror of Docker Hub's
# library/julia, which has no anonymous pull rate limit and no auth.
# Tag matches docker.io/library/julia:1.11-bookworm exactly.
FROM public.ecr.aws/docker/library/julia:1.11-bookworm AS builder

WORKDIR /app

# Copy project files first for better layer caching.
# Manifest.toml is not committed — Pkg.instantiate() resolves from
# Project.toml. Do NOT use `COPY Manifest.toml* .`: Docker's COPY errors
# when a wildcard matches zero files, which broke CI on every PR.
COPY Project.toml .

# Install dependencies
RUN julia --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.precompile()'

# Copy source code
COPY src/ src/
COPY app/ app/
COPY data/reference/ data/reference/
COPY scripts/ scripts/

# Precompile the full application
RUN julia --project=. -e '
    push!(LOAD_PATH, "/app/src");
    include("src/models/abstract.jl");
    include("src/models/hospital.jl");
    include("src/utils/constants.jl");
    include("src/simulation/deterministic.jl");
'

# Stage 2: Production runtime
FROM public.ecr.aws/docker/library/julia:1.11-slim-bookworm AS runtime

# Install runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    libpq5 \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN groupadd --gid 1000 simuser && \
    useradd --uid 1000 --gid simuser --create-home simuser

WORKDIR /app

# Copy compiled artifacts from builder
COPY --from=builder /app/ /app/
COPY --from=builder /root/.julia/ /home/simuser/.julia/

# Copy data directories
COPY data/ data/

# Ensure data directories exist and are writable
RUN mkdir -p data/uploads data/exports data/reference data/sample && \
    chown -R simuser:simuser /app

USER simuser

# Environment variables
ENV JULIA_PROJECT=/app
ENV JULIA_NUM_THREADS=auto
ENV JULIA_DEPOT_PATH=/home/simuser/.julia
ENV GENIE_ENV=prod
ENV PORT=8000
ENV HOST=0.0.0.0

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:${PORT}/api/health || exit 1

EXPOSE 8000

# Start the Genie web application
CMD ["julia", "--project=/app", "--threads=auto", "-e", \
     "include(\"app/app.jl\"); using .HospitalEconomicsApp; start()"]
