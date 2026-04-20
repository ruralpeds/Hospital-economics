# Healthcare Economics Platform - Security Architecture
## Kubernetes + HIPAA Safeguards Design

**Version:** 1.0
**Date:** April 15, 2026
**Classification:** Confidential - Security Architecture

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Network Security](#network-security)
3. [Authentication & Authorization](#authentication--authorization)
4. [Data Protection](#data-protection)
5. [Kubernetes Security](#kubernetes-security)
6. [Monitoring & Audit Logging](#monitoring--audit-logging)
7. [Incident Response](#incident-response)
8. [Compliance Implementation](#compliance-implementation)

---

## Architecture Overview

### 1.1 High-Level Security Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        INTERNET (USERS)                              │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             │ HTTPS/TLS 1.3
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│                   WAF (Web Application Firewall)                      │
│  - Rate limiting (10,000 req/min per IP)                             │
│  - DDoS protection                                                    │
│  - SQL injection prevention                                          │
│  - XSS/CSRF protection                                               │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│              API Gateway (Kong/AWS API Gateway)                       │
│  - TLS termination (certificate pinning)                             │
│  - Request validation (OpenAPI schema)                               │
│  - Rate limiting (per-user, per-endpoint)                            │
│  - CORS policy enforcement                                           │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             ▼
         ┌───────────────────────────────────────┐
         │   Kubernetes Cluster (Production)     │
         │   Namespace: healthcare-prod          │
         │                                       │
         │  ┌────────────────────────────────┐  │
         │  │ Authentication Pod             │  │
         │  │ - JWT token generation         │  │
         │  │ - MFA verification (TOTP/U2F)  │  │
         │  │ - Session management           │  │
         │  └────────────────────────────────┘  │
         │              │                       │
         │              ▼                       │
         │  ┌────────────────────────────────┐  │
         │  │ API Service (Genie.jl)         │  │
         │  │ - Authorization (RBAC)         │  │
         │  │ - Audit logging                │  │
         │  │ - Request encryption           │  │
         │  │ - Error handling               │  │
         │  └────────────────────────────────┘  │
         │              │                       │
         │              ▼                       │
         │  ┌────────────────────────────────┐  │
         │  │ Data Processing Layer          │  │
         │  │ - De-identification            │  │
         │  │ - Data masking                 │  │
         │  │ - Validation                   │  │
         │  │ - Business logic               │  │
         │  └────────────────────────────────┘  │
         │              │                       │
         │              ▼                       │
         │  ┌────────────────────────────────┐  │
         │  │ Secrets Manager (Vault)        │  │
         │  │ - API keys                     │  │
         │  │ - Database credentials         │  │
         │  │ - Encryption keys              │  │
         │  │ - Audit trail                  │  │
         │  └────────────────────────────────┘  │
         │              │                       │
         └──────────────┼───────────────────────┘
                        │
        ┌───────────────┼───────────────┐
        │               │               │
        ▼               ▼               ▼
    ┌────────┐  ┌──────────┐  ┌────────────┐
    │PostgreSQL  │Redis     │  │HSM (Key   │
    │TDE         │Cache     │  │Management)│
    │Encrypted   │(TLS)     │  │           │
    └────────┘  └──────────┘  └────────────┘
        │
        ▼
    ┌──────────────┐
    │S3 Backup     │
    │Encrypted     │
    │(Versioning)  │
    └──────────────┘

┌──────────────────────────────────────────────────────┐
│  Monitoring, Logging & Auditing (Outside Cluster)    │
├──────────────────────────────────────────────────────┤
│  - SIEM (Splunk/ELK Stack)                           │
│  - Audit logs (immutable storage)                    │
│  - Prometheus + Grafana (metrics/alerts)             │
│  - VPC Flow Logs                                     │
└──────────────────────────────────────────────────────┘
```

### 1.2 Security Layers (Defense in Depth)

| Layer | Controls | Technologies |
|-------|----------|---------------|
| **Network** | Firewall, WAF, rate limiting | AWS VPC, WAF, iptables |
| **Transport** | TLS 1.3, certificate pinning | OpenSSL, Let's Encrypt |
| **Application** | Input validation, authentication, RBAC | Genie.jl middleware |
| **Data** | Encryption, tokenization, masking | AES-256-GCM, PostgreSQL TDE |
| **Infrastructure** | Pod security, network policies, RBAC | Kubernetes RBAC, NetworkPolicy |
| **Monitoring** | Audit logging, intrusion detection, alerting | SIEM, Prometheus, VPC Flow Logs |

---

## Network Security

### 2.1 Network Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                          AWS VPC (Private)                        │
│                     10.0.0.0/16                                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  Public Subnet (NAT Gateway, Load Balancer)              │   │
│  │  10.0.1.0/24                                             │   │
│  │  ┌──────────────────────────────────────────────────┐   │   │
│  │  │ Application Load Balancer (ALB)                 │   │   │
│  │  │ - TLS termination                               │   │   │
│  │  │ - Health check (/health)                        │   │   │
│  │  │ - Route to EKS nodes                            │   │   │
│  │  └──────────────────────────────────────────────────┘   │   │
│  └──────────────────────────────────────────────────────────┘   │
│                           │                                      │
├───────────────────────────┼──────────────────────────────────────┤
│                           │                                      │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  Private Subnet (EKS Cluster)                           │   │
│  │  10.0.2.0/24                                            │   │
│  │  ┌────────────────────────────────────────────────────┐ │   │
│  │  │ EKS Node 1 (Worker Node)                          │ │   │
│  │  │ ┌──────────────────────────────────────────────┐  │ │   │
│  │  │ │ Pod: healthcare-economics-api-1              │  │ │   │
│  │  │ └──────────────────────────────────────────────┘  │ │   │
│  │  │ ┌──────────────────────────────────────────────┐  │ │   │
│  │  │ │ Pod: healthcare-economics-auth-1             │  │ │   │
│  │  │ └──────────────────────────────────────────────┘  │ │   │
│  │  └────────────────────────────────────────────────────┘ │   │
│  │  ┌────────────────────────────────────────────────────┐ │   │
│  │  │ EKS Node 2 (Worker Node)                          │ │   │
│  │  │ ┌──────────────────────────────────────────────┐  │ │   │
│  │  │ │ Pod: healthcare-economics-api-2              │  │ │   │
│  │  │ └──────────────────────────────────────────────┘  │ │   │
│  │  └────────────────────────────────────────────────────┘ │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  Data Subnet (Databases, Caches)                         │   │
│  │  10.0.3.0/24                                             │   │
│  │  ┌────────────────────────┐  ┌────────────────────────┐ │   │
│  │  │ PostgreSQL RDS         │  │ Redis Cache            │ │   │
│  │  │ (Multi-AZ, encrypted)  │  │ (Encrypted, TLS)       │ │   │
│  │  └────────────────────────┘  └────────────────────────┘ │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘

Security Groups:
- ALB SG: Allow 443 (HTTPS), block all others
- EKS Node SG: Allow traffic from ALB, deny external
- Database SG: Allow traffic from EKS nodes only (port 5432)
- Redis SG: Allow traffic from EKS nodes only (port 6379)
```

### 2.2 Network Policies (Kubernetes)

```yaml
# Allow ingress from ALB to API pods only
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: api-ingress
  namespace: healthcare-prod
spec:
  podSelector:
    matchLabels:
      app: healthcare-api
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx
    ports:
    - protocol: TCP
      port: 8080

---
# Deny all egress except to databases
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: api-egress
  namespace: healthcare-prod
spec:
  podSelector:
    matchLabels:
      app: healthcare-api
  policyTypes:
  - Egress
  egress:
  # Allow DNS
  - to:
    - namespaceSelector: {}
      podSelector:
        matchLabels:
          k8s-app: kube-dns
    ports:
    - protocol: UDP
      port: 53
  # Allow to PostgreSQL
  - to:
    - podSelector:
        matchLabels:
          app: postgresql
    ports:
    - protocol: TCP
      port: 5432
  # Allow to Redis
  - to:
    - podSelector:
        matchLabels:
          app: redis
    ports:
    - protocol: TCP
      port: 6379
  # Allow to Vault
  - to:
    - namespaceSelector:
        matchLabels:
          name: vault
    ports:
    - protocol: TCP
      port: 8200
```

### 2.3 WAF Rules

```yaml
# AWS WAF Rules for healthcare-economics
AWSTemplateFormatVersion: '2010-09-09'
Resources:
  # Rate limiting
  RateLimitRule:
    Type: AWS::WAFv2::WebACL
    Properties:
      Scope: REGIONAL
      DefaultAction:
        Allow: {}
      Rules:
      - Name: RateLimitRule
        Priority: 0
        Action:
          Block: {}
        Statement:
          RateBasedStatement:
            Limit: 10000
            AggregateKeyType: IP
        VisibilityConfig:
          CloudWatchMetricsEnabled: true
          MetricName: RateLimitRule
          SampledRequestsEnabled: true

  # SQL Injection protection
  SQLiProtection:
    Type: AWS::WAFv2::WebACL
    Properties:
      Rules:
      - Name: AWSManagedRulesSQLiRuleSet
        Priority: 1
        OverrideAction:
          None: {}
        Statement:
          ManagedRuleGroupStatement:
            VendorName: AWS
            Name: AWSManagedRulesSQLiRuleSet
        VisibilityConfig:
          CloudWatchMetricsEnabled: true
          MetricName: SQLiProtection
          SampledRequestsEnabled: true

  # Geographic blocking (optional)
  GeoBlockingRule:
    Type: AWS::WAFv2::WebACL
    Properties:
      Rules:
      - Name: GeoBlockingRule
        Priority: 2
        Action:
          Block: {}
        Statement:
          GeoMatchStatement:
            CountryCodes:
            - CN  # Block China
            - RU  # Block Russia
            - KP  # Block North Korea
        VisibilityConfig:
          CloudWatchMetricsEnabled: true
          MetricName: GeoBlockingRule
          SampledRequestsEnabled: true
```

---

## Authentication & Authorization

### 3.1 Multi-Factor Authentication (MFA) Flow

```
┌──────────────────────────────────────────────────────────────┐
│                   User Login Request                          │
│        Username: user@example.com                             │
│        Password: [encrypted in transit]                       │
└──────────────────┬───────────────────────────────────────────┘
                   │
                   ▼
        ┌──────────────────────────┐
        │ 1. Verify Credentials    │
        │    - Username exists?    │
        │    - Password hash match?│
        │    - Account active?     │
        └──────────────┬───────────┘
                       │
                       ▼
        ┌──────────────────────────────────────┐
        │ 2. MFA Challenge                     │
        │    - Send TOTP QR code OR            │
        │    - Push notification to hardware   │
        │      token                           │
        │    - Prompt for 6-digit code         │
        └──────────────┬───────────────────────┘
                       │
                       ▼
        ┌──────────────────────────────────────┐
        │ 3. Verify MFA Code                   │
        │    - TOTP: Time-based OTP (6 digits) │
        │    - U2F: Hardware token verification│
        │    - Authenticator app: 6 digits     │
        └──────────────┬───────────────────────┘
                       │
                       ▼
        ┌──────────────────────────────────────────────┐
        │ 4. Generate Session                          │
        │    - Create JWT token (RS256 signature)      │
        │    - Include:                                │
        │      * user_id                               │
        │      * roles (Researcher, Admin, etc.)       │
        │      * permissions (RBAC)                    │
        │      * session_start (now)                   │
        │      * exp (1 hour from now)                 │
        │      * iat (issued at)                       │
        │    - Sign with private key (in HSM)          │
        └──────────────┬───────────────────────────────┘
                       │
                       ▼
        ┌──────────────────────────────────────────────┐
        │ 5. Return JWT Token                          │
        │    - Token: eyJhbGc...                       │
        │    - Refresh Token: (for token renewal)      │
        │    - Expires: 1 hour                         │
        └──────────────────────────────────────────────┘
                       │
                       ▼
        ┌──────────────────────────────────────────────┐
        │ 6. Client Makes Authenticated Requests       │
        │    Authorization: Bearer <jwt_token>         │
        └──────────────┬───────────────────────────────┘
                       │
        ┌──────────────┴───────────────────┐
        │                                  │
        ▼                                  ▼
  ┌───────────────────────┐    ┌──────────────────────────┐
  │ Verify JWT Signature  │    │ Check Session Timeout    │
  │ (public key from HSM) │    │ (30 min inactivity)      │
  └───────┬───────────────┘    └────────┬─────────────────┘
          │                              │
          ▼                              ▼
  ┌──────────────────────────────────────────────┐
  │ Extract User Info & Permissions              │
  │ - user_id                                    │
  │ - roles                                      │
  │ - permissions                                │
  └──────────────┬───────────────────────────────┘
                 │
                 ▼
  ┌──────────────────────────────────────────────┐
  │ Verify RBAC for Request                      │
  │ - Does user have required role?              │
  │ - Does user have required permission?        │
  │ - Can user access requested resource?        │
  └──────────────┬───────────────────────────────┘
                 │
          ┌──────┴──────┐
          │             │
    Yes   ▼             ▼   No
  ┌──────────────┐  ┌──────────────────┐
  │ Process      │  │ Return 403       │
  │ Request      │  │ Forbidden        │
  │ + Log Access │  │ + Log Denial     │
  └──────────────┘  └──────────────────┘
```

### 3.2 JWT Token Structure

```json
{
  "header": {
    "alg": "RS256",
    "kid": "prod-key-2026-01",
    "typ": "JWT"
  },
  "payload": {
    "sub": "user@example.com",
    "user_id": "USR123456",
    "name": "John Researcher",
    "roles": ["researcher", "analyst"],
    "permissions": [
      "data:read",
      "cohort:create",
      "analysis:run",
      "report:view"
    ],
    "mfa_verified": true,
    "mfa_method": "totp",
    "session_id": "SES789456",
    "ip_address": "203.0.113.42",
    "iat": 1713193200,
    "exp": 1713196800,
    "purpose": "research"
  },
  "signature": "..."
}
```

### 3.3 RBAC Roles & Permissions

| Role | Permissions | Use Cases |
|------|-------------|-----------|
| **Researcher** | data:read, cohort:create, analysis:run, report:view | Conduct research |
| **Health Economist** | data:read, analysis:run, economic:analyze, report:create | Economic evaluation |
| **Admin** | data:*, user:*, system:configure | System management |
| **Auditor** | audit:read, logs:view, reports:view (read-only) | Compliance/auditing |
| **Data Analyst** | data:read, analysis:run, dashboard:view | Data exploration |

---

## Data Protection

### 4.1 Encryption Architecture

```
┌────────────────────────────────────────────────────────────┐
│                  DATA AT REST (Storage)                     │
├────────────────────────────────────────────────────────────┤
│                                                             │
│  PostgreSQL Database                                       │
│  ┌──────────────────────────────────────────────────────┐ │
│  │ Database-Level Encryption (TDE)                      │ │
│  │ Key: AES-256 (stored in AWS KMS)                    │ │
│  │ All tables encrypted automatically                   │ │
│  │ Including: logs, backups, temp files                 │ │
│  │                                                       │ │
│  │ Individual Column Encryption (selective)             │ │
│  │ Sensitive columns:                                   │ │
│  │  - name → AES-256-GCM                               │ │
│  │  - ssn → AES-256-GCM                                │ │
│  │  - email → AES-256-GCM                              │ │
│  │  - dob → AES-256-GCM                                │ │
│  │  - medical_record_num → AES-256-GCM                │ │
│  │                                                       │ │
│  │ Keys stored in AWS KMS (with rotation)              │ │
│  └──────────────────────────────────────────────────────┘ │
│                                                             │
│  S3 Backup Storage                                         │
│  ┌──────────────────────────────────────────────────────┐ │
│  │ Client-Side Encryption                              │ │
│  │ Key: AES-256-GCM (from HSM)                         │ │
│  │ Backup encryption BEFORE upload to S3               │ │
│  │ Server-side S3 encryption: AES-256                  │ │
│  │ Versioning enabled (prevent accidental deletion)    │ │
│  │ MFA delete: Requires MFA to delete versions         │ │
│  │ Cross-region replication (encrypted)                │ │
│  └──────────────────────────────────────────────────────┘ │
│                                                             │
│  Kubernetes Secrets (Vault integration)                    │
│  ┌──────────────────────────────────────────────────────┐ │
│  │ Secrets in etcd encrypted at rest                   │ │
│  │ Key: Kubernetes encryption key                      │ │
│  │ Regular rotation (monthly)                          │ │
│  │ RBAC: Restrict secret access by role                │ │
│  └──────────────────────────────────────────────────────┘ │
│                                                             │
└────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────┐
│              DATA IN TRANSIT (Network)                      │
├────────────────────────────────────────────────────────────┤
│                                                             │
│  Client → API Gateway                                      │
│  ┌──────────────────────────────────────────────────────┐ │
│  │ TLS 1.3 (no fallback to 1.2)                         │ │
│  │ Cipher suites (AEAD only):                           │ │
│  │  - TLS_AES_256_GCM_SHA384 (preferred)               │ │
│  │  - TLS_CHACHA20_POLY1305_SHA256                      │ │
│  │ Certificate pinning (pin public key)                 │ │
│  │ HSTS headers (Strict-Transport-Security)            │ │
│  │ Certificate valid: 1 year, auto-renewed @ 30 days   │ │
│  └──────────────────────────────────────────────────────┘ │
│                                                             │
│  API Gateway → Kubernetes                                  │
│  ┌──────────────────────────────────────────────────────┐ │
│  │ TLS 1.3 (same as above)                              │ │
│  │ mTLS for Kubernetes services (Istio)                │ │
│  │ Service-to-service encryption                        │ │
│  │ Certificate rotation: 24h                            │ │
│  └──────────────────────────────────────────────────────┘ │
│                                                             │
│  Kubernetes → PostgreSQL                                   │
│  ┌──────────────────────────────────────────────────────┐ │
│  │ PostgreSQL SSL connection (require mode)             │ │
│  │ TLS 1.2+ (database limitation)                       │ │
│  │ Client certificate authentication                    │ │
│  │ Encrypted connection string in Vault                 │ │
│  └──────────────────────────────────────────────────────┘ │
│                                                             │
│  Kubernetes → Redis Cache                                  │
│  ┌──────────────────────────────────────────────────────┐ │
│  │ Redis TLS (Redis 6+)                                 │ │
│  │ Encryption in transit (not at rest for cache)       │ │
│  │ Auth: Redis ACL + password                          │ │
│  └──────────────────────────────────────────────────────┘ │
│                                                             │
└────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────┐
│            KEY MANAGEMENT (HSM - Hardware Security Mod.)   │
├────────────────────────────────────────────────────────────┤
│                                                             │
│  AWS CloudHSM (FIPS 140-2 Level 3)                        │
│  ┌──────────────────────────────────────────────────────┐ │
│  │ Master Encryption Key (MEK)                          │ │
│  │  - Never leaves HSM                                  │ │
│  │  - 256-bit AES key                                   │ │
│  │  - Annual rotation                                   │ │
│  │  - Backup: Split key (Shamir's secret sharing)       │ │
│  │                                                       │ │
│  │ Data Encryption Key (DEK)                            │ │
│  │  - Wrapped by MEK                                    │ │
│  │  - Used for database/S3 encryption                   │ │
│  │  - Cached in memory (with TTL)                       │ │
│  │                                                       │ │
│  │ JWT Signing Keys                                     │ │
│  │  - RSA 4096-bit key pair                             │ │
│  │  - Private key in HSM                                │ │
│  │  - Public key in Kubernetes                          │ │
│  │  - Auto-rotation: Every 90 days                      │ │
│  │  - Grace period: Old keys valid for 30 days         │ │
│  │                                                       │ │
│  │ Audit Trail                                          │
│  │  - All HSM operations logged                         │ │
│  │  - Immutable log (WORM)                             │ │
│  │  - Transmitted to SIEM                              │ │
│  └──────────────────────────────────────────────────────┘ │
│                                                             │
└────────────────────────────────────────────────────────────┘
```

### 4.2 De-identification & Tokenization

```
┌────────────────────────────────────────────────────────────┐
│                  DE-IDENTIFICATION FLOW                     │
├────────────────────────────────────────────────────────────┤
│                                                             │
│  Input: Raw Patient Record                                │
│  ┌────────────────────────────────────────────────────┐   │
│  │ patient_id: UNKNOWN-12345                          │   │
│  │ name: "John Smith" ← PII                           │   │
│  │ dob: "1975-03-15" ← PII                            │   │
│  │ ssn: "123-45-6789" ← PII                           │   │
│  │ zip_code: "10001" ← PII (need first 3 only)        │   │
│  │ email: "john@example.com" ← PII                    │   │
│  │ med_rec_num: "MR-87654" ← PII                      │   │
│  │ diagnosis_code: "E11.0" ← OK (no PII)              │   │
│  │ procedure_code: "99213" ← OK (no PII)              │   │
│  │ cost: $1,500.00 ← OK (aggregate, no PII)           │   │
│  └────────────────────────────────────────────────────┘   │
│                      │                                     │
│                      ▼                                     │
│  ┌────────────────────────────────────────────────────┐   │
│  │ SAFE HARBOR DE-IDENTIFICATION                      │   │
│  │ (Remove 18 HIPAA identifiers)                       │   │
│  └────────────────────┬───────────────────────────────┘   │
│                       │                                    │
│  ┌────────────────────┴───────────────────────────────┐   │
│  │ 1. Remove identifiers:                            │   │
│  │    - name ✓                                        │   │
│  │    - ssn ✓                                         │   │
│  │    - email ✓                                       │   │
│  │    - med_rec_num ✓                                 │   │
│  │    - phone/fax ✓                                   │   │
│  │    - url/ip ✓                                      │   │
│  │    - photos/biometric ✓                            │   │
│  │    - dates (except year) ✓                         │   │
│  │    - vehicle ids ✓                                 │   │
│  │    - account numbers ✓                             │   │
│  │    - certificate numbers ✓                         │   │
│  │    - license plates ✓                              │   │
│  │    - device serial numbers ✓                       │   │
│  │    - web URLs ✓                                    │   │
│  │    - unique ID / code ✓                            │   │
│  │                                                     │   │
│  │ 2. Keep/modify allowed elements:                   │   │
│  │    - zip_code: "10001" → "100" (first 3 digits)   │   │
│  │    - birth_year: keep year only (not full DOB)    │   │
│  │    - diagnosis_code: "E11.0" (no change)          │   │
│  │    - procedure_code: "99213" (no change)          │   │
│  │    - cost: $1,500.00 (no change)                  │   │
│  │                                                     │   │
│  │ 3. Assign study ID:                               │   │
│  │    - Generate random: STUDY-00001                 │   │
│  │    - Keep mapping table (encrypted, access locked)│   │
│  └────────────────────┬───────────────────────────────┘   │
│                       │                                    │
│                       ▼                                    │
│  Output: De-identified Record                             │
│  ┌────────────────────────────────────────────────────┐   │
│  │ study_id: "STUDY-00001"                            │   │
│  │ birth_year: 1975 (NOT full DOB)                    │   │
│  │ zip_code: "100" (first 3 digits only)              │   │
│  │ diagnosis_code: "E11.0"                            │   │
│  │ procedure_code: "99213"                            │   │
│  │ cost: $1,500.00                                    │   │
│  │                                                     │   │
│  │ ✗ NO: name, dob, ssn, email, med_rec_num, etc.   │   │
│  └────────────────────────────────────────────────────┘   │
│                                                             │
└────────────────────────────────────────────────────────────┘

TOKENIZATION (Alternative to De-identification)
┌────────────────────────────────────────────────────────────┐
│                                                             │
│  Original: patient_id = "12345", name = "John Smith"       │
│                       │                                    │
│                       ▼                                    │
│  Token Generator (One-way hash)                           │
│  SHA256(patient_id + secret_salt) = "abc123..."           │
│                       │                                    │
│                       ▼                                    │
│  Tokenized: patient_token = "abc123..."                   │
│  Original mapping stored separately:                      │
│  - Location: Encrypted Vault                             │
│  - Access: Restricted to authorized staff                │
│  - Reversible: Only if keys available                    │
│                                                             │
└────────────────────────────────────────────────────────────┘
```

---

## Kubernetes Security

### 5.1 Pod Security & RBAC

```yaml
# Pod Security Policy (strict)
apiVersion: policy/v1beta1
kind: PodSecurityPolicy
metadata:
  name: restricted-healthcare
spec:
  privileged: false
  allowPrivilegeEscalation: false
  requiredDropCapabilities:
  - ALL
  volumes:
  - 'configMap'
  - 'emptyDir'
  - 'projected'
  - 'secret'
  - 'downwardAPI'
  - 'persistentVolumeClaim'
  hostNetwork: false
  hostIPC: false
  hostPID: false
  runAsUser:
    rule: 'MustRunAsNonRoot'
  seLinux:
    rule: 'MustRunAs'
    seLinuxOptions:
      level: "s0:c123,c456"
  readOnlyRootFilesystem: true
  runAsNonRoot: true

---
# Kubernetes RBAC: Service Account
apiVersion: v1
kind: ServiceAccount
metadata:
  name: healthcare-api
  namespace: healthcare-prod

---
# RBAC: Role
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: healthcare-api
  namespace: healthcare-prod
rules:
# Allow reading secrets (but not creating/deleting)
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list"]
  resourceNames:
  - "database-credentials"
  - "vault-credentials"
  - "jwt-signing-key"

# Allow configmap access
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["get", "list"]

# Allow pod logs (for debugging only)
- apiGroups: [""]
  resources: ["pods/log"]
  verbs: ["get"]

---
# RBAC: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: healthcare-api
  namespace: healthcare-prod
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: healthcare-api
subjects:
- kind: ServiceAccount
  name: healthcare-api
  namespace: healthcare-prod

---
# Network Policy: Strict egress
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: healthcare-api-egress
  namespace: healthcare-prod
spec:
  podSelector:
    matchLabels:
      app: healthcare-api
  policyTypes:
  - Egress
  egress:
  # Allow DNS
  - to:
    - namespaceSelector: {}
      podSelector:
        matchLabels:
          k8s-app: kube-dns
    ports:
    - protocol: UDP
      port: 53
  # Allow PostgreSQL (only)
  - to:
    - podSelector:
        matchLabels:
          app: postgresql
    ports:
    - protocol: TCP
      port: 5432
  # Allow Vault (only)
  - to:
    - namespaceSelector:
        matchLabels:
          name: vault
    ports:
    - protocol: TCP
      port: 8200
```

### 5.2 Secrets Management (Vault Integration)

```hcl
# Vault configuration
path "secret/data/healthcare/*" {
  capabilities = ["read", "list"]
}

path "pki/issue/healthcare-api" {
  capabilities = ["create", "update"]
}

path "auth/token/renew-self" {
  capabilities = ["update"]
}

# Kubernetes auth for pods
auth {
  method "kubernetes" {
    description = "Kubernetes auth for EKS pods"
    type = "kubernetes"

    config {
      kubernetes_host = "https://kubernetes.default.svc"
      kubernetes_ca_cert = file("/var/run/secrets/kubernetes.io/serviceaccount/ca.crt")
      token_reviewer_jwt = file("/var/run/secrets/kubernetes.io/serviceaccount/token")
    }

    role "healthcare-api" {
      bound_service_account_names = ["healthcare-api"]
      bound_service_account_namespaces = ["healthcare-prod"]
      policies = ["healthcare-api"]
      ttl = 1h
    }
  }
}
```

---

## Monitoring & Audit Logging

### 6.1 Audit Logging Architecture

```
┌──────────────────────────────────────────────────────────────┐
│              ALL SYSTEM COMPONENTS                             │
│  (API, Database, Auth, Kubernetes, Infrastructure)           │
└────────────────────┬─────────────────────────────────────────┘
                     │
         ┌───────────┼───────────┐
         │           │           │
         ▼           ▼           ▼
    ┌────────┐  ┌────────┐  ┌────────┐
    │API     │  │DB      │  │K8s     │
    │Logs    │  │Logs    │  │Logs    │
    └────┬───┘  └────┬───┘  └────┬───┘
         │           │            │
         └───────────┼────────────┘
                     │
                     ▼
        ┌──────────────────────────┐
        │ Log Aggregation Layer    │
        │ (Fluentd / Filebeat)     │
        │                          │
        │ - Normalize format       │
        │ - Add timestamps         │
        │ - Enrich metadata        │
        │ - Verify completeness    │
        └────┬─────────────────────┘
             │
             ▼
        ┌──────────────────────────┐
        │ SIEM (Splunk / ELK)      │
        │                          │
        │ - Real-time ingestion    │
        │ - Parsing & indexing     │
        │ - Alerting rules         │
        │ - Dashboard/reports      │
        └────┬─────────────────────┘
             │
         ┌───┴────┐
         │        │
         ▼        ▼
    ┌────────┐  ┌─────────────────┐
    │Alerts  │  │Immutable Storage│
    │to Team │  │(S3/WORM)        │
    │        │  │6-year retention │
    └────────┘  └─────────────────┘
```

### 6.2 Audit Log Schema

```sql
CREATE TABLE audit_logs (
    audit_log_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id VARCHAR(255) NOT NULL,
    timestamp TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    event_type VARCHAR(50) NOT NULL,  -- PHI_ACCESS, DATA_INGESTION, ANALYSIS, etc.
    resource VARCHAR(255) NOT NULL,    -- Table name, endpoint, etc.
    action VARCHAR(50) NOT NULL,       -- SELECT, INSERT, UPDATE, DELETE, LOGIN, etc.
    result VARCHAR(50) NOT NULL,       -- SUCCESS, DENIED, ERROR
    error_message TEXT,
    ip_address INET,
    user_agent VARCHAR(2048),
    purpose_code VARCHAR(50),          -- TREATMENT, PAYMENT, OPERATIONS, RESEARCH

    -- Immutable after insert
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    hash_previous BYTEA,               -- Hash of previous row (chain integrity)
    hash_current BYTEA NOT NULL        -- Hash of this row
);

-- Index for common queries
CREATE INDEX idx_audit_user_time ON audit_logs(user_id, timestamp DESC);
CREATE INDEX idx_audit_event ON audit_logs(event_type, timestamp DESC);
CREATE INDEX idx_audit_resource ON audit_logs(resource, timestamp DESC);

-- Immutable log trigger
CREATE OR REPLACE FUNCTION prevent_audit_log_modification()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'Audit logs cannot be modified or deleted';
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER audit_log_immutable
BEFORE UPDATE OR DELETE ON audit_logs
FOR EACH ROW EXECUTE FUNCTION prevent_audit_log_modification();
```

### 6.3 Real-time Alerts

```yaml
# Splunk Alert Rules
---
# Alert 1: Multiple failed login attempts
name: "Failed Login Attempts"
search: |
  event_type=LOGIN result=DENIED
  | stats count by user_id
  | where count > 5
alert_threshold: immediate
actions:
  - email: security@example.com
  - slack: #security-alerts
  - incident: create

---
# Alert 2: Unusual data access
name: "Large PHI Bulk Access"
search: |
  event_type=PHI_ACCESS action=SELECT
  | stats count by user_id
  | where count > 1000 in 5m
alert_threshold: immediate
actions:
  - email: security@example.com
  - slack: #security-alerts
  - block: quarantine user

---
# Alert 3: After-hours access
name: "Off-Hours PHI Access"
search: |
  event_type=PHI_ACCESS
  | where hour > 18 OR hour < 6
  | stats count by user_id, hour
alert_threshold: 15 minutes
actions:
  - email: manager@example.com
  - logging: increased

---
# Alert 4: Access denied for admin
name: "Admin Access Denied"
search: |
  event_type=* result=DENIED user_id=admin_*
alert_threshold: immediate
actions:
  - email: security@example.com
  - escalate: CTO
```

---

## Incident Response

### 7.1 Security Incident Response Plan

```
┌─────────────────────────────────────────────────────────┐
│  SECURITY INCIDENT DETECTED                              │
│  (Alert from SIEM, user report, or routine audit)       │
└──────────────────────┬──────────────────────────────────┘
                       │
         ┌─────────────┴─────────────┐
         │                           │
         ▼                           ▼
   ┌──────────────┐           ┌──────────────┐
   │ DETECT       │           │ RESPOND      │
   ├──────────────┤           ├──────────────┤
   │ - Severity?  │           │ - Contain    │
   │ - Scope?     │           │ - Assess     │
   │ - PHI/PII?   │           │ - Mitigate   │
   │ - Ongoing?   │           │ - Communicate│
   └──────┬───────┘           └──────┬───────┘
          │                          │
          └──────────────┬───────────┘
                         │
         ┌───────────────┼───────────────┐
         │               │               │
         ▼               ▼               ▼
    MINOR         MEDIUM            CRITICAL
    (SLA: 24h)    (SLA: 4h)         (SLA: 1h)
         │               │               │
         ▼               ▼               ▼
    ┌────────┐      ┌────────┐      ┌────────┐
    │Log &   │      │Notify  │      │Activate│
    │Monitor │      │Manager │      │IR Team │
    │        │      │        │      │        │
    └────┬───┘      └────┬───┘      └────┬───┘
         │              │               │
         └──────────────┼───────────────┘
                        │
         ┌──────────────┴──────────────┐
         │                             │
         ▼                             ▼
    ┌─────────────┐            ┌──────────────┐
    │ INVESTIGATE │            │ INVESTIGATE  │
    │ - Root cause│            │ - Scope full │
    │ - Extent    │            │ - All logs   │
    │ - Timeline  │            │ - Affected   │
    │             │            │ - Evidence   │
    └────┬────────┘            └──────┬───────┘
         │                           │
         └───────────────┬───────────┘
                         │
         ┌───────────────┴──────────────┐
         │                              │
         ▼                              ▼
    ┌──────────────┐          ┌────────────────┐
    │ CONTAIN      │          │ NOTIFY (if PHI)│
    │ - Patch      │          │ - Patients     │
    │ - Rotate key │          │ - Regulators   │
    │ - Revoke acc │          │ - Media (500+) │
    │ - Block IPs  │          │ - Within 60d   │
    └────┬─────────┘          └────────┬───────┘
         │                            │
         └────────────────┬───────────┘
                          │
         ┌────────────────┴──────────────┐
         │                               │
         ▼                               ▼
    ┌──────────────┐          ┌──────────────┐
    │ REMEDIATE    │          │ DOCUMENT     │
    │ - Fix cause  │          │ - Timeline   │
    │ - Harden     │          │ - Root cause │
    │ - Test       │          │ - Actions    │
    │ - Deploy     │          │ - Lessons    │
    └────┬─────────┘          └──────┬───────┘
         │                           │
         └───────────────┬───────────┘
                         │
                         ▼
              ┌──────────────────────┐
              │ CLOSE & REVIEW       │
              │ - Team debrief       │
              │ - Update procedures  │
              │ - Monitor for recur. │
              └──────────────────────┘
```

### 7.2 Incident Response Team

| Role | Responsibility | On-call |
|------|---|---|
| **Incident Commander** | Coordinate response, decisions | 24/7 |
| **Security Lead** | Technical investigation | 24/7 |
| **Database Admin** | Database analysis, recovery | 24/7 |
| **Kubernetes Ops** | Infrastructure investigation | 24/7 |
| **Legal Counsel** | Breach notification, compliance | Business hours |
| **Communications** | Internal/external messaging | Business hours |

---

## Compliance Implementation

### 8.1 HIPAA Controls Mapping

| HIPAA Requirement | Control Implementation | Verification |
|---|---|---|
| **Unique User ID** | JWT with user_id claim | Audit logs show user_id |
| **Emergency Access** | Break-glass procedure (MFA + notification) | Annual test, documented approvals |
| **Access Control** | RBAC with principle of least privilege | Quarterly role reviews |
| **Audit Logging** | All PHI access logged (who, what, when, where) | SIEM dashboards, regular audits |
| **Encryption at Rest** | AES-256-GCM in PostgreSQL + S3 | Annual key audit, penetration test |
| **Encryption in Transit** | TLS 1.3 for all connections | SSL Labs grade A, certificate valid |
| **Key Management** | HSM with annual rotation | Key audit trail in HSM logs |
| **Data Integrity** | Checksums, digital signatures | Backup restoration tests |
| **Backup/Recovery** | Daily incremental, weekly full | RTO ≤ 4h, RPO ≤ 1h, annual test |
| **Workforce Security** | Background checks, training, termination procedures | Personnel file audit annually |
| **Risk Assessment** | Annual formal assessment | Documented, remediation tracked |
| **Sanction Policy** | Disciplinary procedures documented | Training records |
| **Information Access** | Minimum necessary principle | Access review quarterly |
| **Security Awareness** | Annual HIPAA training | 100% completion tracked |
| **Encryption/Decryption** | Secure key management, documented procedures | Tested in disaster recovery |

### 8.2 Security Controls Checklist

**Monthly:**
- ☐ Review audit logs for anomalies
- ☐ Verify backups completed successfully
- ☐ Check certificate expiration dates
- ☐ Review failed login attempts

**Quarterly:**
- ☐ Access control review (RBAC audits)
- ☐ Key rotation (JWT signing keys)
- ☐ Security patch assessment
- ☐ Disaster recovery test (at least once/year)

**Annually:**
- ☐ Formal HIPAA risk assessment
- ☐ Penetration testing
- ☐ Security audit (external)
- ☐ HIPAA training (all staff)
- ☐ Vendor security assessment
- ☐ Incident response plan test

---

**END OF SECURITY ARCHITECTURE DOCUMENT**
