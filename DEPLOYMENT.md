# Deployment Guide — Rural Hospital Economics Simulator

## Prerequisites

- Docker and Docker Compose (v2.0+)
- Domain name with DNS configured (for SSL)
- At minimum: 4 CPU cores, 8 GB RAM

## Environment Setup

1. Copy the environment template and fill in production values:

```bash
cp .env.example .env
```

2. Generate a secure secret token:

```bash
julia -e 'using Random; println(randstring(64))'
```

3. Set a strong database password:

```bash
# In .env, set these values:
SECRET_TOKEN=<generated-token>
POSTGRES_PASSWORD=<strong-random-password>
DATABASE_URL=postgresql://rhsim:<password>@postgres:5432/rhsim_prod
GENIE_ENV=prod
ALLOWED_ORIGIN=https://your-domain.com
```

**Important:** Never commit `.env` to version control. It is excluded via `.gitignore`.

## Docker Deployment

### Build and Start

```bash
cd docker
docker compose up -d --build
```

This starts four services:
- **app** — Julia application server on port 8000
- **postgres** — PostgreSQL 16 database
- **redis** — Redis cache and job queue
- **nginx** — Reverse proxy on ports 80/443

### Verify

```bash
# Check all services are running
docker compose ps

# Test health endpoint
curl http://localhost/api/health
```

## SSL/TLS Configuration

### Option 1: Let's Encrypt (Recommended)

1. Install certbot on the host machine
2. Generate certificates:

```bash
sudo certbot certonly --standalone -d your-domain.com
```

3. Copy certificates to the nginx volume:

```bash
sudo cp /etc/letsencrypt/live/your-domain.com/fullchain.pem docker/certs/
sudo cp /etc/letsencrypt/live/your-domain.com/privkey.pem docker/certs/
```

4. In `docker/nginx.conf`, uncomment the SSL directives:

```nginx
listen 443 ssl http2;
ssl_certificate /etc/nginx/certs/fullchain.pem;
ssl_certificate_key /etc/nginx/certs/privkey.pem;
ssl_protocols TLSv1.2 TLSv1.3;
```

5. Enable HTTP-to-HTTPS redirect by uncommenting the redirect line in the server block.

6. Restart nginx:

```bash
docker compose restart nginx
```

### Option 2: Custom Certificates

Place your certificate files in `docker/certs/` as `fullchain.pem` and `privkey.pem`, then follow steps 4-6 above.

## Security Checklist

- [ ] `SECRET_TOKEN` is set to a cryptographically random 64+ character string
- [ ] `POSTGRES_PASSWORD` is a strong random password (not the example value)
- [ ] `ALLOWED_ORIGIN` is set to your actual domain (not `*`)
- [ ] SSL/TLS is enabled with valid certificates
- [ ] `.env` file is NOT in version control
- [ ] Firewall allows only ports 80, 443 (and SSH for management)
- [ ] Docker container runs as non-root user (`simuser`)
- [ ] Database is not exposed to the public network (only `5432` on internal Docker network)

## File Import Security

The application restricts file imports to these server-side directories:
- `data/uploads/` — User-uploaded files
- `data/reference/` — CMS reference data
- `data/sample/` — Sample hospital profiles

File exports are written to `data/exports/`. All filenames are sanitized to prevent path traversal.

## Rate Limiting

Nginx enforces rate limits on API endpoints:
- General API: 30 requests/second per IP (burst: 50)
- Simulation endpoints: 5 requests/minute per IP (burst: 3)

## Monitoring

### Health Check

The Docker health check polls `/api/health` every 30 seconds. The endpoint returns:

```json
{
  "status": "ok",
  "version": "0.3.0",
  "engines": ["deterministic", "monte_carlo", "abm", "system_dynamics", "des"]
}
```

### Logs

- Application logs: `docker compose logs app`
- Nginx access/error logs: `docker compose logs nginx`
- Production log files: written to `/app/logs/` inside the container

## Scaling

### Simulation Performance

- Monte Carlo with 10,000 iterations: ~5-15 seconds (4 threads)
- ABM with 5,000 agents: ~10-30 seconds
- System Dynamics: ~1-3 seconds

Set `JULIA_NUM_THREADS=auto` to use all available cores. For heavy simulation workloads, allocate at least 8 GB RAM to the app container.

### Resource Limits

Default limits in `docker-compose.yml`:
- App: 4 CPUs, 8 GB RAM
- PostgreSQL: 2 CPUs, 2 GB RAM
- Redis: 1 CPU, 512 MB RAM
- Nginx: 1 CPU, 256 MB RAM

## Backup

### Database Backup

```bash
docker compose exec postgres pg_dump -U rhsim rhsim_prod > backup_$(date +%Y%m%d).sql
```

### Restore

```bash
cat backup_20260329.sql | docker compose exec -T postgres psql -U rhsim rhsim_prod
```

## Updating

```bash
git pull origin main
docker compose up -d --build
```

The multi-stage Dockerfile ensures Julia packages are cached in build layers. Rebuilds that don't change `Project.toml` will reuse the cached dependency layer.
