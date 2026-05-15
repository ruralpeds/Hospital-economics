# Production-Readiness Plan — `ruralpeds/Hospital-economics`

## Context

The repo (Julia 1.11, ~125k LOC, v1.1.0) is **analytically rich but operationally aspirational**. The finance engine, simulation paradigms, optimization, and MBA-domain analytics (P0–P2 gaps closed per `MISSING_FEATURES.md`) are largely real. However, the platform's HIPAA / enterprise / security claims in `SECURITY_ARCHITECTURE.md`, `JULIA_HIPAA_STANDARDS.md`, and `DATA_DICTIONARY.md` are mostly **documented, not implemented**. To actually run this in production handling PHI — or even non-PHI rural-hospital benchmarking data for paying customers — a concrete set of gaps must close. This file lists them in priority order, plus the major missing analytic functions the repo's own gap docs flag.

---

## P0 — Ship-blockers (cannot run in prod without these)

### 1. Authentication & authorization actually enforced
- **State:** `GenieAuthentication` is a dep; migration `app/db/migrations/002_create_users.jl` defines a users table with `role` (admin/analyst/viewer) and `password_hash`. No middleware enforces auth on routes.
- **Do:** Add an auth middleware applied in `app/routes.jl` (1,731 lines, currently public). Enforce role gates on controllers in `app/controllers/`. Add session timeout + secure cookie config in `app/app.jl`. JWT for API, MFA for admin.

### 2. Encryption at rest for PHI columns
- **State:** No AES-256-GCM module exists anywhere in `src/` despite docs.
- **Do:** Add `src/security/encryption.jl` (AES-256-GCM via libsodium/Nettle), wire column-level encrypt/decrypt into SearchLight models. Key from env or KMS (AWS KMS / GCP KMS / Vault); HSM optional.

### 3. Persist audit logs
- **State:** `src/data_ingestion/audit_logger.jl` is in-memory only.
- **Do:** Add migration for `audit_logs` table (append-only / partitioned by month / `REVOKE UPDATE,DELETE`). Make the logger write through SearchLight. Add controller middleware that emits an entry per request (user_id, route, action, resource, status, IP, latency).

### 4. Real DB layer
- **State:** 8 SearchLight migrations (`app/db/migrations/001_…` → `008_…`, 553 LOC). No full ORM models exposed; no connection pooling; TimescaleDB hypertables not created.
- **Do:** Add SearchLight models for the core tables, a `config/initializers/db.jl` with pool config, and `SELECT create_hypertable(...)` for time-series tables (`encounters`, `claims`, `metrics`, `audit_logs`).

### 5. Kubernetes + IaC
- **State:** Dockerfile + docker-compose work. No `k8s/`, `helm/`, or `terraform/` despite the runbook describing EKS/RDS/ALB.
- **Do:** Add minimal Helm chart (Deployment, Service, Ingress, HPA, NetworkPolicy, SealedSecrets) and a `terraform/` module for VPC + EKS + RDS-Postgres-with-Timescale + ALB + ACM + KMS.

### 6. Health, readiness, metrics endpoints
- **State:** Dockerfile references `/api/health`; route not located.
- **Do:** Add `/healthz` (liveness), `/readyz` (DB + cache reachable), `/metrics` (Prometheus, via `Prometheus.jl` or hand-rolled exposition). Wire latency, error-rate, in-flight request gauges.

### 7. Integration & E2E tests that touch the stack
- **State:** ~79 unit tests; no DB-backed or HTTP-driven integration tests visible. Playwright `e2e/` exists but config not verified.
- **Do:** Add a `test/integration/` suite that spins up Postgres via docker-compose, runs migrations, exercises auth + a representative analytic endpoint. Gate CI on Playwright + integration green.

### 8. Repo hygiene that blocks a clean build
- Delete duplicates: `Makefile 2`, `Economics-textbook-v1 2`.
- Move root-level `test_modules_4_5_integration.jl` into `test/`.
- Move `Aqua` from `[deps]` to `[extras]` / test-only.
- Consolidate `ci.yml` + `test.yml` (currently duplicate test jobs).
- Split `app/routes.jl` (1,731 LOC) by domain.

---

## P1 — Important before opening to outside users

9. **Rate limiting + CSRF** middleware on the Genie app.
10. **SIEM shipping** of the audit logs (Fluent Bit → Splunk/ELK/CloudWatch).
11. **Secrets mgmt** beyond `.env.example` (Vault, AWS Secrets Manager, or SealedSecrets).
12. **Request logging middleware** with correlation IDs; structured JSON logs.
13. **OpenTelemetry tracing** spans across HTTP → SearchLight → JuMP solves.
14. **Backup / DR** runbook actually wired (`pg_dump` cron + S3, RTO/RPO target tested).
15. **Coverage gate** in CI: block PRs on >1pp drop (`ci.yml` only enforces a 60% floor).
16. **Aqua.jl** quality gate enabled in CI.
17. **Dependency security scan** (e.g., `julia-actions/julia-runtest` + `Trivy` for the image).
18. **CSP / security headers** in the Genie response pipeline.

---

## P2 — Major missing analytic functions (from the repo's own gap docs)

The README / Phase-3 plan promises capabilities that are still stubs or absent:

- **AI/ML closure & billing-error prediction** at "95%+ accuracy / 20% billing-error reduction." Today only `closure_ml.jl` (~9 KB, LACE + logistic regression) and `readmission_risk.jl` (LACE) exist. Need real trained models, model cards, monitoring.
- **Real-time anomaly detection** — promised in Phase-3 success criteria; no module under `src/analytics/` or `src/streaming/` implements it.
- **EHR automated sync** beyond CMS connectors — no FHIR R4 client, no 837 claim parser (despite `REQUIREMENTS_DOCUMENT.md` listing both). `src/data_ingestion/` currently covers HCRIS only.
- **Streaming pipeline** — `src/streaming/StreamingIngestion.jl` is a ~10 KB MVP; Kafka/Redis Streams + windowed analytics not wired.
- **`src/clinical_integration/`** — `ClinicalEconomicCoupling.jl` (212 B) and `PhysiologicalModel.jl` (224 B) are placeholders.
- **CFO one-pager (F-03)** route exists in `app/routes.jl:34` but rendering not independently verified; needs sign-off pass.

---

## Critical files to touch when executing

- `app/app.jl`, `app/routes.jl`, `app/controllers/*` — auth, CSRF, rate limit, headers.
- `app/db/migrations/00{2,9,10}_*.jl` — new migrations for audit_logs, encrypted columns, hypertables.
- `src/security/` (new) — `encryption.jl`, `auth.jl`, `rbac.jl`.
- `src/data_ingestion/audit_logger.jl` — switch to persistent backend.
- `src/observability/` (new) — Prometheus exporter, OTel tracer, structured logger.
- `src/data_ingestion/` — add `fhir_client.jl`, `x12_837_parser.jl`.
- `src/clinical_integration/*.jl` — replace stubs.
- `k8s/` (new), `terraform/` (new), `docker/Dockerfile` (multi-arch, distroless runtime).
- `.github/workflows/ci.yml` + `test.yml` — consolidate; add Trivy, Aqua, integration job, coverage-drop gate.
- `test/integration/` (new) — DB + HTTP end-to-end tests.

## Reuse what already exists

- `src/data_ingestion/audit_logger.jl` — keep API, swap storage.
- `src/data_ingestion/deidentifiers.jl` — already implements HIPAA Safe Harbor; reuse in any export path.
- `packages/FinanceEngine/` and `packages/RuralCore/` — 73 real modules; do not re-architect.
- `docker/docker-compose.yml` (app + postgres + redis + nginx) — use as the integration-test fixture.

## Verification (when work is done)

1. `julia --project=. -e 'using Pkg; Pkg.test()'` green, including new `test/integration/`.
2. `docker compose up` then `curl /readyz` returns 200 only after Postgres + migrations are ready; `/metrics` exposes Prometheus text.
3. `playwright test` green against the compose stack (login → MFA → dashboard → analytic).
4. Forced-failure tests: tampered JWT → 401; viewer hitting admin route → 403; DELETE on `audit_logs` row → DB error; request without TLS → redirect.
5. `terraform plan` clean against a sandbox AWS account; Helm `--dry-run` clean on a kind cluster.
6. Coverage report ≥ current baseline; Aqua + Trivy gates pass; CI runs in <15 min.

## Out of scope for this plan

Building the ML models themselves, full EHR vendor certifications, SOC 2 audit, and HITRUST cert — those are post-MVP and require sustained effort beyond a single readiness pass.
