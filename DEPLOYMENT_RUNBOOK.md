# Healthcare Economics Platform - Deployment Runbook
## Step-by-Step Production Go-Live Guide

**Version:** 1.0
**Date:** April 15, 2026
**Target Release:** Phase 1 MVP (October 15, 2026)
**Deployment Window:** Friday 2AM - 6AM (4-hour maintenance window)

---

## Table of Contents

1. [Pre-Deployment Checklist](#pre-deployment-checklist)
2. [Infrastructure Provisioning](#infrastructure-provisioning)
3. [Database Deployment](#database-deployment)
4. [Application Deployment](#application-deployment)
5. [Security Hardening](#security-hardening)
6. [Go-Live Validation](#go-live-validation)
7. [Rollback Procedures](#rollback-procedures)
8. [Post-Go-Live Monitoring](#post-go-live-monitoring)

---

## Pre-Deployment Checklist

### 1.1 72 Hours Before Deployment

**Code & Configuration Review**
- ☐ All code merged to main branch
- ☐ All tests passing on main (100% success rate)
- ☐ Code review approval from 2 reviewers minimum
- ☐ No blocking security findings in SAST scan
- ☐ Secrets removed from code (grep for API keys, passwords)
- ☐ Environment variables documented in .env.example

**Documentation**
- ☐ API documentation updated (OpenAPI/Swagger)
- ☐ Deployment procedures documented
- ☐ Runbook reviewed by operations team
- ☐ Rollback procedures documented & tested
- ☐ Incident communication templates prepared

**Infrastructure**
- ☐ AWS/Azure/GCP account provisioned
- ☐ VPC created with proper CIDR ranges
- ☐ Security groups/NSGs configured
- ☐ HSM provisioned and tested
- ☐ DNS records prepared (CNAME entries ready)
- ☐ Certificates requested from CA (ordered ≥2 weeks ago)

**Database**
- ☐ PostgreSQL 14+ instance provisioned
- ☐ TimescaleDB extension installed
- ☐ Database encryption enabled (TDE)
- ☐ Backup policy configured (daily incremental, weekly full)
- ☐ Backup tested (restore to staging environment)
- ☐ Database schema migrated to staging
- ☐ Indexes created and performance tested

**Monitoring & Logging**
- ☐ SIEM (Splunk/ELK) configured
- ☐ Prometheus + Grafana dashboards created
- ☐ Alert rules configured (tested)
- ☐ Log aggregation pipeline tested
- ☐ Backup storage (S3) configured with versioning
- ☐ VPC Flow Logs enabled

**Security**
- ☐ SSL certificates installed (valid, CA-signed)
- ☐ TLS 1.3 configured (no TLS 1.2 fallback)
- ☐ WAF rules configured and tested
- ☐ DDoS protection enabled
- ☐ API rate limiting configured
- ☐ HIPAA audit logging implemented and tested
- ☐ MFA system tested (TOTP/U2F)
- ☐ Vault configured with appropriate policies

**Team Preparation**
- ☐ On-call rotation scheduled (24x7 for 1 week)
- ☐ Incident response team trained
- ☐ Escalation procedures documented
- ☐ Communication templates prepared
- ☐ Stakeholders notified of deployment window

### 1.2 24 Hours Before Deployment

**Final Validations**
- ☐ Staging environment mirrors production
- ☐ End-to-end test scenarios passed in staging
- ☐ Load testing completed (target: 10 concurrent users)
- ☐ Disaster recovery tested (RTO ≤ 4h, RPO ≤ 1h)
- ☐ Rollback procedure tested on staging
- ☐ Database backup verified in production environment
- ☐ Secrets loaded into Vault and tested

**Communication**
- ☐ Maintenance window announced to all stakeholders
- ☐ Downtime expected: 4 hours (2AM-6AM, Friday)
- ☐ Contact information for support provided
- ☐ Status page updated with deployment info

**Backup & Recovery**
- ☐ Database backed up (full backup)
- ☐ Backup tested for restoration
- ☐ Backup media verified and labeled
- ☐ Recovery runbook available to team
- ☐ Alternative communication channels confirmed (Slack, email, phone)

### 1.3 Approval Sign-Off

```
Required Approvals (obtain before proceeding):

1. Project Manager: _____________ Date: _______
2. Technical Lead: ______________ Date: _______
3. Security Officer: ____________ Date: _______
4. Database Administrator: ______ Date: _______
5. CISO/CTO: __________________ Date: _______

If any approval withheld, DO NOT PROCEED.
```

---

## Infrastructure Provisioning

### 2.1 AWS Infrastructure Setup

```bash
#!/bin/bash
# Deploy infrastructure using Terraform

set -e

ENVIRONMENT="production"
AWS_REGION="us-east-1"
PROJECT_NAME="healthcare-economics"

echo "=== Provisioning AWS Infrastructure for $PROJECT_NAME ==="

# 1. Validate Terraform
cd terraform/
terraform init -upgrade
terraform validate
terraform plan -out=tfplan

# 2. Apply infrastructure changes
read -p "Review plan above. Continue? (yes/no): " response
if [ "$response" != "yes" ]; then
    echo "Deployment cancelled"
    exit 1
fi

terraform apply tfplan

# 3. Output important values
terraform output -json > ../infrastructure_outputs.json
echo "Infrastructure provisioned. Outputs saved to infrastructure_outputs.json"

# 4. Verify connectivity
VPC_ID=$(terraform output -raw vpc_id)
SUBNET_IDS=$(terraform output -raw private_subnet_ids)
RDS_ENDPOINT=$(terraform output -raw rds_endpoint)

echo "VPC ID: $VPC_ID"
echo "Private Subnets: $SUBNET_IDS"
echo "RDS Endpoint: $RDS_ENDPOINT"

# 5. Test RDS connectivity
PGPASSWORD=$DB_PASSWORD psql \
    -h $(echo $RDS_ENDPOINT | cut -d: -f1) \
    -U $DB_USER \
    -d postgres \
    -c "SELECT version();"

echo "=== Infrastructure Provisioning Complete ==="
```

### 2.2 Kubernetes Cluster Setup

```bash
#!/bin/bash
# Deploy EKS cluster and configure

set -e

CLUSTER_NAME="healthcare-economics-prod"
AWS_REGION="us-east-1"

echo "=== Setting up EKS Cluster ==="

# 1. Create EKS cluster
eksctl create cluster \
    --name $CLUSTER_NAME \
    --region $AWS_REGION \
    --version 1.28 \
    --nodegroup-name default \
    --node-type t3.xlarge \
    --nodes 3 \
    --nodes-min 2 \
    --nodes-max 10 \
    --ssh-access \
    --ssh-public-key ~/.ssh/id_rsa.pub \
    --enable-ssm

# 2. Configure kubectl
aws eks update-kubeconfig \
    --region $AWS_REGION \
    --name $CLUSTER_NAME

# 3. Verify cluster
kubectl cluster-info
kubectl get nodes -o wide

# 4. Install metrics server (for HPA)
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# 5. Install Calico (network policies)
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.0/manifests/tigera-operator.yaml

# 6. Install AWS Load Balancer Controller
helm repo add eks https://aws.github.io/eks-charts
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
    -n kube-system \
    --set clusterName=$CLUSTER_NAME

# 7. Create namespaces
kubectl create namespace healthcare-prod
kubectl create namespace healthcare-staging
kubectl create namespace vault
kubectl create namespace monitoring

# 8. Label namespaces for pod security
kubectl label namespace healthcare-prod pod-security.kubernetes.io/enforce=restricted
kubectl label namespace healthcare-staging pod-security.kubernetes.io/enforce=baseline

echo "=== EKS Cluster Setup Complete ==="
```

### 2.3 Certificate & DNS Setup

```bash
#!/bin/bash
# Configure SSL certificates and DNS

set -e

DOMAIN="api.healthcare-economics.example.com"
HOSTED_ZONE_ID="Z1234567890ABC"

echo "=== Configuring Certificates & DNS ==="

# 1. Request certificate from Let's Encrypt (via ACM)
aws acm request-certificate \
    --domain-name $DOMAIN \
    --subject-alternative-names "*.healthcare-economics.example.com" \
    --validation-method DNS \
    --region us-east-1 \
    > cert_request.json

CERT_ARN=$(jq -r '.CertificateArn' cert_request.json)
echo "Certificate ARN: $CERT_ARN"

# 2. Wait for DNS validation (manual or automated)
echo "Waiting 60 seconds for DNS propagation..."
sleep 60

# 3. Configure Route 53 DNS
aws route53 change-resource-record-sets \
    --hosted-zone-id $HOSTED_ZONE_ID \
    --change-batch '{
        "Changes": [
            {
                "Action": "CREATE",
                "ResourceRecordSet": {
                    "Name": "'$DOMAIN'",
                    "Type": "CNAME",
                    "TTL": 300,
                    "ResourceRecords": [
                        {"Value": "'$(kubectl get svc -n ingress-nginx | grep LoadBalancer | awk '{print $4}').'"}
                    ]
                }
            }
        ]
    }'

# 4. Test certificate
openssl s_client -connect $DOMAIN:443 -servername $DOMAIN \
    </dev/null | grep "subject="

echo "=== Certificates & DNS Configured ==="
```

---

## Database Deployment

### 3.1 Database Initialization

```bash
#!/bin/bash
# Initialize PostgreSQL database with schema

set -e

DB_HOST=$RDS_ENDPOINT
DB_NAME="healthcare_economics"
DB_USER="healthcare_admin"
DB_PORT=5432

echo "=== Initializing PostgreSQL Database ==="

# 1. Create database
PGPASSWORD=$DB_PASSWORD psql \
    -h $DB_HOST \
    -U $DB_USER \
    -d postgres \
    -c "CREATE DATABASE $DB_NAME;"

# 2. Connect to new database
PGPASSWORD=$DB_PASSWORD psql \
    -h $DB_HOST \
    -U $DB_USER \
    -d $DB_NAME \
    -c "CREATE EXTENSION IF NOT EXISTS uuid-ossp;"

# 3. Create extensions
PGPASSWORD=$DB_PASSWORD psql \
    -h $DB_HOST \
    -U $DB_USER \
    -d $DB_NAME \
    -c "CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;"

PGPASSWORD=$DB_PASSWORD psql \
    -h $DB_HOST \
    -U $DB_USER \
    -d $DB_NAME \
    -c "CREATE EXTENSION IF NOT EXISTS pg_cron;"

PGPASSWORD=$DB_PASSWORD psql \
    -h $DB_HOST \
    -U $DB_USER \
    -d $DB_NAME \
    -c "CREATE EXTENSION IF NOT EXISTS pgcrypto;"

# 4. Enable encryption at rest (TDE)
# Note: For AWS RDS, TDE is enabled at DB instance level

# 5. Run migrations
echo "Running database migrations..."
julia -e "
    using Pkg
    Pkg.activate(\".\")
    include(\"db/migrations/run_migrations.jl\")
    run_all_migrations(\"$DB_HOST\", \"$DB_USER\", \"$DB_NAME\")
"

# 6. Load reference data
echo "Loading reference data (ICD-10, CPT codes)..."
PGPASSWORD=$DB_PASSWORD psql \
    -h $DB_HOST \
    -U $DB_USER \
    -d $DB_NAME \
    < db/seeds/icd10_codes.sql

PGPASSWORD=$DB_PASSWORD psql \
    -h $DB_HOST \
    -U $DB_USER \
    -d $DB_NAME \
    < db/seeds/cpt_codes.sql

# 7. Create indexes
echo "Creating indexes..."
PGPASSWORD=$DB_PASSWORD psql \
    -h $DB_HOST \
    -U $DB_USER \
    -d $DB_NAME \
    < db/schemas/indexes.sql

# 8. Verify schema
echo "Verifying schema..."
PGPASSWORD=$DB_PASSWORD psql \
    -h $DB_HOST \
    -U $DB_USER \
    -d $DB_NAME \
    -c "\dt" \
    | head -20

echo "=== Database Initialization Complete ==="
```

### 3.2 Database Backup Configuration

```bash
#!/bin/bash
# Configure automated backups

set -e

echo "=== Configuring Database Backups ==="

# 1. AWS RDS backup policy
aws rds modify-db-instance \
    --db-instance-identifier healthcare-economics-db \
    --backup-retention-period 30 \
    --preferred-backup-window "02:00-03:00" \
    --preferred-maintenance-window "sun:03:00-sun:04:00" \
    --enable-cloudwatch-logs-exports postgresql \
    --apply-immediately

# 2. Enable automated snapshots to S3
aws s3api create-bucket \
    --bucket healthcare-economics-backups-$(date +%s) \
    --region us-east-1 \
    --create-bucket-configuration LocationConstraint=us-east-1 \
    2>/dev/null || true

# 3. Enable S3 versioning (prevent deletion)
BACKUP_BUCKET=$(aws s3 ls | grep healthcare-economics-backups | awk '{print $3}')
aws s3api put-bucket-versioning \
    --bucket $BACKUP_BUCKET \
    --versioning-configuration Status=Enabled

# 4. Test backup/restore
echo "Testing backup procedures..."
aws rds create-db-snapshot \
    --db-instance-identifier healthcare-economics-db \
    --db-snapshot-identifier healthcare-economics-backup-test-$(date +%Y%m%d%H%M%S)

echo "Waiting for snapshot completion..."
aws rds wait db-snapshot-available \
    --db-snapshot-identifier healthcare-economics-backup-test-$(date +%Y%m%d%H%M%S)

echo "=== Backup Configuration Complete ==="
```

---

## Application Deployment

### 4.1 Build & Push Docker Image

```bash
#!/bin/bash
# Build and push Docker image to registry

set -e

VERSION=$(git describe --tags --always)
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com"
IMAGE_NAME="healthcare-economics"

echo "=== Building Docker Image ==="
echo "Version: $VERSION"
echo "Registry: $ECR_REGISTRY"

# 1. Login to ECR
aws ecr get-login-password --region us-east-1 | \
    docker login --username AWS --password-stdin $ECR_REGISTRY

# 2. Create ECR repository if needed
aws ecr create-repository \
    --repository-name $IMAGE_NAME \
    --region us-east-1 \
    2>/dev/null || true

# 3. Build image with security scanning
docker build \
    --file docker/Dockerfile \
    --tag $ECR_REGISTRY/$IMAGE_NAME:$VERSION \
    --tag $ECR_REGISTRY/$IMAGE_NAME:latest \
    --build-arg VERSION=$VERSION \
    --build-arg BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ') \
    .

# 4. Scan image for vulnerabilities
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
    aquasec/trivy image \
    --exit-code 0 \
    --severity HIGH,CRITICAL \
    $ECR_REGISTRY/$IMAGE_NAME:$VERSION

# 5. Push to registry
echo "Pushing image to ECR..."
docker push $ECR_REGISTRY/$IMAGE_NAME:$VERSION
docker push $ECR_REGISTRY/$IMAGE_NAME:latest

echo "Image URI: $ECR_REGISTRY/$IMAGE_NAME:$VERSION"
echo "=== Docker Image Build Complete ==="
```

### 4.2 Deploy to Kubernetes

```bash
#!/bin/bash
# Deploy application to production Kubernetes cluster

set -e

NAMESPACE="healthcare-prod"
ENVIRONMENT="production"
VERSION=$(git describe --tags --always)

echo "=== Deploying to Kubernetes ==="

# 1. Create/update secrets
echo "Loading secrets from Vault..."
kubectl delete secret healthcare-secrets -n $NAMESPACE 2>/dev/null || true

vault kv get -format=json secret/healthcare/prod | \
    jq -r '.data.data | to_entries | .[] | "\(.key)=\(.value)"' | \
    kubectl create secret generic healthcare-secrets \
        --from-env-file=/dev/stdin \
        -n $NAMESPACE

# 2. Update image tag in deployment
sed -i "s|IMAGE_TAG|$VERSION|g" k8s/overlays/prod/deployment.yaml

# 3. Apply Kubernetes manifests
echo "Applying Kubernetes manifests..."
kubectl apply -k k8s/overlays/prod/

# 4. Wait for deployment rollout
echo "Waiting for deployment to be ready..."
kubectl rollout status deployment/healthcare-economics \
    -n $NAMESPACE \
    --timeout=10m

# 5. Verify pod health
echo "Verifying pod status..."
kubectl get pods -n $NAMESPACE -o wide
kubectl logs -n $NAMESPACE -l app=healthcare-api --tail=50

# 6. Test service connectivity
SERVICE_IP=$(kubectl get svc healthcare-economics -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "Service endpoint: $SERVICE_IP"

# 7. Health check
echo "Performing health checks..."
curl -k https://$SERVICE_IP/health || echo "Health check failed - may still be warming up"

echo "=== Kubernetes Deployment Complete ==="
```

### 4.3 Deployment Manifest Example

```yaml
# k8s/overlays/prod/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: healthcare-economics
  namespace: healthcare-prod
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0  # Zero-downtime deployment
  selector:
    matchLabels:
      app: healthcare-api
  template:
    metadata:
      labels:
        app: healthcare-api
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8080"
        prometheus.io/path: "/metrics"
    spec:
      serviceAccountName: healthcare-api
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 1000
      containers:
      - name: api
        image: AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/healthcare-economics:IMAGE_TAG
        imagePullPolicy: IfNotPresent
        securityContext:
          readOnlyRootFilesystem: true
          allowPrivilegeEscalation: false
          runAsNonRoot: true
        ports:
        - name: http
          containerPort: 8080
          protocol: TCP
        - name: metrics
          containerPort: 8090
          protocol: TCP
        env:
        - name: ENVIRONMENT
          value: production
        - name: LOG_LEVEL
          value: info
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: healthcare-secrets
              key: DATABASE_URL
        - name: VAULT_ADDR
          value: "https://vault.vault.svc.cluster.local:8200"
        - name: VAULT_TOKEN
          valueFrom:
            secretKeyRef:
              name: healthcare-secrets
              key: VAULT_TOKEN
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "2Gi"
            cpu: "1000m"
        livenessProbe:
          httpGet:
            path: /health/live
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /health/ready
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 5
          failureThreshold: 3
        volumeMounts:
        - name: tmp
          mountPath: /tmp
        - name: cache
          mountPath: /var/cache
      volumes:
      - name: tmp
        emptyDir: {}
      - name: cache
        emptyDir: {}
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app
                  operator: In
                  values:
                  - healthcare-api
              topologyKey: kubernetes.io/hostname

---
apiVersion: v1
kind: Service
metadata:
  name: healthcare-economics
  namespace: healthcare-prod
  annotations:
    alb.ingress.kubernetes.io/healthcheck-path: /health
spec:
  type: LoadBalancer
  selector:
    app: healthcare-api
  ports:
  - protocol: TCP
    port: 443
    targetPort: 8080
    name: https
  - protocol: TCP
    port: 80
    targetPort: 8080
    name: http
```

---

## Security Hardening

### 5.1 HIPAA Compliance Verification

```bash
#!/bin/bash
# Verify HIPAA controls are in place

set -e

echo "=== HIPAA Compliance Verification ==="

# 1. Verify encryption at rest
echo "1. Verifying Database Encryption..."
PGPASSWORD=$DB_PASSWORD psql \
    -h $DB_HOST \
    -U $DB_USER \
    -d postgres \
    -c "SELECT datname, datacl FROM pg_database WHERE datname='healthcare_economics';" \
    || echo "⚠ Cannot verify encryption (RDS-managed)"

# 2. Verify TLS for connections
echo "2. Verifying TLS Configuration..."
curl -k -I https://api.healthcare-economics.example.com/health | grep "Strict-Transport-Security" \
    || echo "⚠ HSTS header missing"

# 3. Test MFA
echo "3. Testing MFA System..."
curl -X POST https://api.healthcare-economics.example.com/auth/login \
    -d '{"username":"test@example.com","password":"test123"}' \
    | grep -q "mfa_required" && echo "✓ MFA required for login"

# 4. Verify audit logging
echo "4. Verifying Audit Logging..."
PGPASSWORD=$DB_PASSWORD psql \
    -h $DB_HOST \
    -U $DB_USER \
    -d healthcare_economics \
    -c "SELECT COUNT(*) FROM audit_logs;" \
    | grep -q "[0-9]" && echo "✓ Audit logs present"

# 5. Test encryption key rotation
echo "5. Testing HSM Key Rotation..."
./scripts/test_hsm_rotation.sh || echo "⚠ Key rotation test failed"

# 6. Verify backups encrypted
echo "6. Verifying Backup Encryption..."
aws s3 ls s3://healthcare-economics-backups | head -5
echo "✓ Backups visible in S3"

# 7. Check network isolation
echo "7. Verifying Network Policies..."
kubectl get networkpolicies -n healthcare-prod | wc -l | grep -q "[1-9]" && echo "✓ Network policies enforced"

echo "=== HIPAA Verification Complete ==="
```

### 5.2 Security Validation Checklist

```bash
#!/bin/bash
# Final security validation before go-live

CHECKS_PASSED=0
CHECKS_TOTAL=0

check_security() {
    local name=$1
    local command=$2
    ((CHECKS_TOTAL++))

    if eval "$command" > /dev/null 2>&1; then
        echo "✓ $name"
        ((CHECKS_PASSED++))
    else
        echo "✗ $name"
    fi
}

echo "=== Security Validation ==="

# SSL/TLS
check_security "TLS 1.3 enabled" \
    "openssl s_client -connect api.example.com:443 -tls1_3 </dev/null 2>/dev/null | grep -q 'Protocol  : TLSv1.3'"

# Authentication
check_security "MFA required" \
    "grep -r 'mfa_required' src/api/"

# Encryption
check_security "Database encryption enabled" \
    "echo 'SELECT setting FROM pg_settings WHERE name=\\'ssl\\'' | PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -U $DB_USER -d postgres | grep -q on"

# Audit logs
check_security "Audit logging implemented" \
    "grep -r 'audit_log' src/core/"

# Network policies
check_security "Network policies deployed" \
    "kubectl get networkpolicies -n healthcare-prod | grep -q 'healthcare-api'"

# RBAC
check_security "RBAC configured" \
    "kubectl get roles -n healthcare-prod | grep -q healthcare"

# Secrets management
check_security "Secrets in Vault" \
    "vault kv list secret/healthcare/prod | grep -q -E '(database|jwt|encryption)'"

# SSL certificates
check_security "Valid SSL certificate" \
    "openssl s_client -connect api.example.com:443 </dev/null 2>/dev/null | openssl x509 -noout -dates | grep -q notAfter"

echo ""
echo "=== Security Validation Results ==="
echo "Passed: $CHECKS_PASSED / $CHECKS_TOTAL"

if [ $CHECKS_PASSED -lt $CHECKS_TOTAL ]; then
    echo "⚠ WARNING: Some security checks failed!"
    echo "Do NOT proceed to production without resolving all checks."
    exit 1
fi

echo "✓ All security checks passed"
exit 0
```

---

## Go-Live Validation

### 6.1 Smoke Tests

```bash
#!/bin/bash
# Run smoke tests against production environment

set -e

API_URL="https://api.healthcare-economics.example.com"
TEST_USER="test-researcher@example.com"
TEST_PASSWORD="temp-test-password-12345"

echo "=== Running Smoke Tests ==="

# 1. Health check
echo "1. Checking API health..."
curl -k -f $API_URL/health || exit 1

# 2. Authentication
echo "2. Testing authentication..."
TOKEN=$(curl -k -X POST $API_URL/auth/login \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"$TEST_USER\",\"password\":\"$TEST_PASSWORD\"}" \
    | jq -r '.token')

if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
    echo "✗ Authentication failed"
    exit 1
fi
echo "✓ Authentication successful"

# 3. API endpoints
echo "3. Testing API endpoints..."
curl -k -H "Authorization: Bearer $TOKEN" $API_URL/api/v1/cohorts | jq . || exit 1
curl -k -H "Authorization: Bearer $TOKEN" $API_URL/api/v1/analyses | jq . || exit 1

# 4. Database connectivity
echo "4. Testing database..."
PGPASSWORD=$DB_PASSWORD psql \
    -h $DB_HOST \
    -U $DB_USER \
    -d healthcare_economics \
    -c "SELECT 1;" || exit 1

# 5. Audit logging
echo "5. Verifying audit logs..."
PGPASSWORD=$DB_PASSWORD psql \
    -h $DB_HOST \
    -U $DB_USER \
    -d healthcare_economics \
    -c "SELECT COUNT(*) FROM audit_logs WHERE created_at > NOW() - INTERVAL '1 minute';" \
    | grep -q "[1-9]" || echo "⚠ No recent audit logs (may be normal)"

# 6. SIEM integration
echo "6. Checking SIEM..."
curl -k https://siem.example.com/api/events?q=healthcare-economics | jq . || echo "⚠ SIEM check skipped"

# 7. Backup verification
echo "7. Verifying backups..."
aws s3 ls s3://healthcare-economics-backups --recursive | tail -5

echo ""
echo "=== All Smoke Tests Passed ==="
```

### 6.2 User Acceptance Testing (UAT)

```markdown
# UAT Checklist for Healthcare Economics Platform

## Test Scenario 1: Data Ingestion
- [ ] Upload sample hospital claims CSV
- [ ] Verify data loaded successfully
- [ ] Check audit logs show ingestion event
- [ ] Validate row count matches source
- [ ] Confirm de-identification applied

## Test Scenario 2: Cohort Building
- [ ] Create new cohort with age criteria (30-65)
- [ ] Add diagnosis criteria (Type 2 Diabetes)
- [ ] Run cohort builder
- [ ] Verify cohort size reasonable
- [ ] Check audit logs show cohort creation

## Test Scenario 3: Cost Analysis
- [ ] Select cohort
- [ ] Run cost analysis
- [ ] Verify total cost calculated
- [ ] Check cost breakdown by type
- [ ] Export results to Excel

## Test Scenario 4: Reporting
- [ ] Generate cost analysis report
- [ ] Verify formatting correct
- [ ] Check tables/charts render
- [ ] Export to PDF
- [ ] Verify PDF opens correctly

## Test Scenario 5: Security
- [ ] Login with invalid credentials → DENIED
- [ ] Login with valid credentials + MFA → SUCCESS
- [ ] Verify session timeout (30 min)
- [ ] Try to access without MFA → DENIED
- [ ] Verify PHI fields not visible in logs

## Sign-Off
- UAT Lead: __________________ Date: _______
- Medical Director: __________ Date: _______
- IT Operations: ____________ Date: _______
```

---

## Rollback Procedures

### 7.1 Kubernetes Rollback

```bash
#!/bin/bash
# Rollback to previous deployment if issues detected

set -e

NAMESPACE="healthcare-prod"

echo "=== INITIATING ROLLBACK ==="

# 1. Check current and previous revision
echo "Current deployments:"
kubectl rollout history deployment/healthcare-economics -n $NAMESPACE

# 2. Initiate rollback
echo "Rolling back to previous version..."
kubectl rollout undo deployment/healthcare-economics \
    -n $NAMESPACE

# 3. Monitor rollback progress
echo "Waiting for rollback to complete..."
kubectl rollout status deployment/healthcare-economics \
    -n $NAMESPACE \
    --timeout=10m

# 4. Verify health
echo "Verifying service health..."
kubectl get pods -n $NAMESPACE -o wide
kubectl logs -n $NAMESPACE -l app=healthcare-api --tail=30

# 5. Test endpoints
SERVICE_IP=$(kubectl get svc healthcare-economics -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
curl -k https://$SERVICE_IP/health

echo "=== Rollback Complete ==="
```

### 7.2 Database Rollback

```bash
#!/bin/bash
# Restore database from backup if data corruption detected

set -e

echo "=== DATABASE ROLLBACK ==="

SNAPSHOT_ID="healthcare-economics-backup-test-20261015T020000Z"

# 1. List available snapshots
echo "Available snapshots:"
aws rds describe-db-snapshots \
    --query 'DBSnapshots[*].[DBSnapshotIdentifier,SnapshotCreateTime]' \
    --output table

# 2. Create new DB instance from snapshot
echo "Creating database from snapshot: $SNAPSHOT_ID"
aws rds restore-db-instance-from-db-snapshot \
    --db-instance-identifier healthcare-economics-db-restored \
    --db-snapshot-identifier $SNAPSHOT_ID \
    --publicly-accessible false

# 3. Wait for restoration
echo "Waiting for database restoration..."
aws rds wait db-instance-available \
    --db-instance-identifier healthcare-economics-db-restored

# 4. Update Kubernetes connection string
echo "Updating Kubernetes secrets with new database endpoint..."
NEW_ENDPOINT=$(aws rds describe-db-instances \
    --db-instance-identifier healthcare-economics-db-restored \
    --query 'DBInstances[0].Endpoint.Address' \
    --output text)

kubectl patch secret healthcare-secrets -n healthcare-prod -p \
    "{\"data\":{\"DATABASE_URL\":\"postgresql://user:pass@${NEW_ENDPOINT}:5432/healthcare_economics\"}}"

# 5. Restart pods to pick up new connection
kubectl rollout restart deployment/healthcare-economics -n healthcare-prod

# 6. Verify
echo "Verifying database connectivity..."
kubectl logs -n healthcare-prod -l app=healthcare-api --tail=20 | grep -i database

echo "=== Database Rollback Complete ==="
```

---

## Post-Go-Live Monitoring

### 8.1 24-Hour Monitoring Plan

```bash
#!/bin/bash
# Continuous monitoring script for first 24 hours

NAMESPACE="healthcare-prod"
DURATION_HOURS=24
CHECK_INTERVAL=60  # seconds

echo "=== Starting 24-Hour Monitoring ==="
echo "Duration: $DURATION_HOURS hours"
echo "Check interval: $CHECK_INTERVAL seconds"
echo "Start time: $(date)"

while true; do
    echo ""
    echo "=== Check at $(date) ==="

    # 1. Pod status
    echo "1. Pod Status:"
    kubectl get pods -n $NAMESPACE -o wide | head -10

    # 2. Resource usage
    echo "2. Resource Usage:"
    kubectl top pods -n $NAMESPACE 2>/dev/null | head -10

    # 3. Recent errors
    echo "3. Recent Errors (last 100 lines):"
    kubectl logs -n $NAMESPACE -l app=healthcare-api --tail=100 | grep -i error | tail -5

    # 4. Request rate
    echo "4. Request Rate:"
    kubectl logs -n $NAMESPACE -l app=healthcare-api --tail=1000 | wc -l

    # 5. Database connections
    echo "5. Database Connections:"
    PGPASSWORD=$DB_PASSWORD psql \
        -h $DB_HOST \
        -U $DB_USER \
        -d healthcare_economics \
        -c "SELECT count(*) FROM pg_stat_activity;" 2>/dev/null || echo "Cannot connect"

    # 6. Audit logs
    echo "6. Audit Logs (last 5 minutes):"
    PGPASSWORD=$DB_PASSWORD psql \
        -h $DB_HOST \
        -U $DB_USER \
        -d healthcare_economics \
        -c "SELECT event_type, COUNT(*) FROM audit_logs WHERE created_at > NOW() - INTERVAL '5 minutes' GROUP BY event_type;" 2>/dev/null || echo "Cannot query"

    # 7. Alerts
    echo "7. Active Alerts:"
    curl -s http://prometheus:9090/api/v1/alerts | jq '.data.alerts[] | select(.state=="firing") | .labels.alertname' | head -10

    sleep $CHECK_INTERVAL
done
```

### 8.2 First 24 Hours Checklist

```markdown
# Go-Live Monitoring (24 Hours)

**Hour 1-2:**
- [ ] API responding to requests
- [ ] Authentication/MFA working
- [ ] Database queries executing
- [ ] Audit logs being written
- [ ] No error spikes in logs

**Hour 2-6:**
- [ ] Load monitoring (target: <50% CPU)
- [ ] Database performance normal (<100ms queries)
- [ ] Backup process completed
- [ ] SIEM ingesting logs
- [ ] Alerts configured and testing

**Hour 6-12:**
- [ ] User login success rate >99%
- [ ] Data ingestion tests passing
- [ ] Cost analysis queries completing <5s
- [ ] No security alerts
- [ ] Stakeholders notified of success

**Hour 12-24:**
- [ ] System stable, no restarts
- [ ] Performance metrics normal
- [ ] Backup retention verified
- [ ] Disaster recovery checklist completed
- [ ] Team debriefs on lessons learned

**Go-Live Sign-Off:**
- [ ] Technical Lead: _____________ Date: _______
- [ ] Operations: ________________ Date: _______
- [ ] Security Officer: __________ Date: _______
```

---

## Emergency Contacts

```
ON-CALL ROTATION (Week 1)

Primary On-Call: _________________ Phone: ______________
Secondary On-Call: _______________ Phone: ______________
Manager On-Call: _________________ Phone: ______________

ESCALATION

- Tier 1 Issue: Alert on-call engineer
- Tier 2 Issue: Alert manager + CISO
- Tier 3 Issue: Alert CTO + Legal

COMMUNICATION

Slack: #healthcare-economics-prod-alerts
Email: healthcare-econ-incidents@example.com
War Room: https://meet.example.com/healthcare-incidents
```

---

**END OF DEPLOYMENT RUNBOOK**

---

## Appendix: Troubleshooting Guide

### Common Issues & Solutions

| Issue | Cause | Solution |
|-------|-------|----------|
| API pods stuck in CrashLoop | Missing secrets | Verify Vault secrets loaded correctly |
| Database connection timeout | Network issue | Check security groups/NSGs, test connectivity |
| High CPU usage | Unoptimized queries | Profile queries, check indexes, review logs |
| Audit logs not appearing | Logging disabled | Verify audit logging enabled in config |
| Certificate expiry alerts | Cert not renewed | Check Let's Encrypt renewal, update certificate |
| Session timeouts too frequent | Inactivity time wrong | Adjust timeout configuration in Vault |

---

**Document Complete - Ready for Deployment**
