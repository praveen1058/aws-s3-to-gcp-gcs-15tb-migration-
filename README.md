# AWS S3 → Google Cloud Storage: 15 TB Production Migration

## Executive Summary

Designed and implemented a production-grade migration strategy to move approximately **15 TB of object data from Amazon S3 to Google Cloud Storage** with minimal application disruption.

The migration focused on:

* Zero/near-zero data loss
* Minimal production downtime
* Automated data validation
* Object count and byte-level reconciliation
* Checksum/integrity validation
* Incremental synchronization for continuously changing data
* Secure cross-cloud access
* Monitoring and failure handling
* Rollback capability
* Infrastructure and configuration automation

> **Note:** This repository contains sanitized architecture, automation, and validation logic. No production credentials, customer data, bucket names, or sensitive configuration are included.

---

## Architecture

```text
                    AWS
             ┌─────────────────┐
             │   S3 Bucket      │
             │     ~15 TB       │
             └────────┬────────┘
                      │
                      │ Secure cross-cloud transfer
                      │
                      ▼
          ┌───────────────────────┐
          │ Storage Transfer      │
          │ Service               │
          │                       │
          │ - Initial transfer    │
          │ - Incremental sync    │
          │ - Retry handling      │
          │ - Integrity checks    │
          └───────────┬───────────┘
                      │
                      ▼
             ┌─────────────────┐
             │ Google Cloud    │
             │ Storage Bucket  │
             │     ~15 TB      │
             └────────┬────────┘
                      │
                      ▼
             ┌─────────────────┐
             │ Validation /    │
             │ Reconciliation  │
             └─────────────────┘
```

---

# Migration Objectives

| Requirement           | Target               |
| --------------------- | -------------------- |
| Source                | AWS S3               |
| Destination           | Google Cloud Storage |
| Data volume           | ~15 TB               |
| Migration type        | Cross-cloud          |
| Production            | Yes                  |
| Data loss             | 0                    |
| Object count mismatch | 0                    |
| Size mismatch         | 0                    |
| Checksum mismatch     | 0                    |
| Source deletion       | Disabled initially   |
| Rollback              | Required             |
| Downtime              | Minimal              |

---

# Migration Strategy

The migration was divided into five phases.

### Phase 1 — Discovery

Before moving any data, collect:

* Total object count
* Total object size
* Object distribution by prefix
* Large-object distribution
* Small-object distribution
* Existing encryption configuration
* Storage class
* Object versioning requirements
* Application write/read patterns

Example baseline:

```text
Source: AWS S3

Objects:       <REDACTED>
Total size:    ~15 TB
Prefixes:      <REDACTED>
Largest file:  <REDACTED>
```

---

### Phase 2 — Initial Migration

Use Google Cloud Storage Transfer Service for the bulk migration.

```text
S3
 │
 │ Initial bulk transfer
 ▼
Storage Transfer Service
 │
 ▼
GCS
```

The source bucket is retained during the migration.

Source deletion is disabled to maintain rollback capability.

---

### Phase 3 — Incremental Synchronization

Because the production application may continue writing to S3, the migration is not treated as a one-time copy.

```text
Initial Transfer
       │
       ▼
Application continues writing to S3
       │
       ▼
Incremental Transfer
       │
       ▼
Final synchronization
```

Before cutover:

1. Stop or quiesce application writes.
2. Run final synchronization.
3. Validate source and destination.
4. Switch application configuration to GCS.

---

# Data Validation Strategy

Data validation is performed at multiple levels.

## 1. Object Count

```text
S3 object count
        ==
GCS object count
```

Expected:

```text
Difference = 0
```

## 2. Total Size

```text
S3 total bytes
        ==
GCS total bytes
```

Expected:

```text
Difference = 0 bytes
```

## 3. Object-Level Validation

For each object:

```text
Object name
Object size
Checksum where available
```

are compared between source and destination.

Expected:

```text
Missing objects       = 0
Extra objects         = 0
Size mismatches       = 0
Checksum mismatches   = 0
```

---

# Production Cutover

```text
                 Production
                     │
                     ▼
             ┌───────────────┐
             │     AWS S3    │
             └───────┬───────┘
                     │
              Final Sync
                     │
                     ▼
             ┌───────────────┐
             │     GCS       │
             └───────┬───────┘
                     │
               Validation
                     │
                     ▼
             Application
               Cutover
```

### Cutover checklist

* [ ] Initial migration completed
* [ ] Failed objects = 0
* [ ] Object counts match
* [ ] Total bytes match
* [ ] Object-level reconciliation completed
* [ ] Final incremental sync completed
* [ ] Application writes stopped/quiesced
* [ ] Final validation completed
* [ ] Application pointed to GCS
* [ ] Smoke tests completed
* [ ] Monitoring enabled
* [ ] AWS S3 retained for rollback

---

# Rollback Strategy

The source S3 bucket is not deleted immediately after migration.

If application validation fails after cutover:

```text
Application
     │
     │ rollback
     ▼
AWS S3
```

Rollback triggers include:

* Unexpected missing objects
* Application read failures
* Permission/IAM issues
* Performance degradation
* Unexpected object consistency issues
* Business validation failure

The S3 source remains available until the defined rollback window expires.

---

# Security

No long-lived credentials are stored in this repository.

Security controls include:

* Least-privilege IAM
* Dedicated migration identity
* No credentials in Git
* Encryption at rest
* Encryption in transit
* Bucket access logging/auditing
* Restricted destination access
* Secret management through cloud-native mechanisms

Example principle:

```text
Migration Identity
      │
      ├── S3: List/Get only
      │
      └── GCS: Required write permissions only
```

---

# Observability

Migration monitoring tracks:

* Bytes transferred
* Objects transferred
* Transfer rate
* Failed objects
* Retry count
* Remaining objects
* Remaining bytes
* Validation results

Example migration dashboard:

```text
Migration Progress
──────────────────────────────
Total data:       15 TB
Transferred:      XX TB
Remaining:        XX GB
Objects:          XXXXX
Failed:           0
Validation:       PASS
```

---

# Failure Handling

Common failure scenarios and responses:

| Failure                           | Action                     |
| --------------------------------- | -------------------------- |
| Individual object failure         | Retry / investigate        |
| Permission failure                | Validate IAM               |
| Destination quota issue           | Investigate quota          |
| Network/API transient error       | Retry                      |
| Object mismatch                   | Reconcile affected objects |
| Application failure after cutover | Roll back                  |
| Validation failure                | Do not complete cutover    |

---

# Cost Considerations

The migration was evaluated for:

* AWS data transfer/egress costs
* GCP storage costs
* GCP operations
* Transfer Service costs where applicable
* Temporary infrastructure
* Long-term storage class selection

Cost estimation should be performed before production execution.

Example:

```text
Estimated data volume:
15 TB

AWS:
  Storage
  Data transfer/egress
  API requests

GCP:
  Storage
  Operations
  Network
```

Actual production costs should be replaced with measured values where available.

---

# Key Engineering Decisions

### Why Storage Transfer Service?

For a large cross-cloud object migration, a managed transfer service avoids maintaining a fleet of custom transfer VMs and provides transfer management, retries, monitoring, and integrity handling.

### Why not simply use `aws s3 sync`?

A simple CLI synchronization can work for smaller migrations, but for a production-scale 15 TB cross-cloud migration I wanted:

* Managed transfer orchestration
* Better operational visibility
* Retry handling
* Migration scheduling
* Production reconciliation
* Reduced operational overhead

### Why keep S3 after migration?

The source is retained to provide a rollback path and prevent an irreversible migration decision before application validation is complete.

---

# Lessons Learned

1. Data migration is primarily a **data integrity and operational risk problem**, not simply a file-copy problem.
2. Object count and total bytes alone are insufficient for strong validation.
3. Production writes must be explicitly handled during migration.
4. The final synchronization and cutover require a controlled change window.
5. Source data should not be deleted immediately after migration.
6. Least-privilege cross-cloud access is critical.
7. Large numbers of small objects can behave very differently from a small number of large objects.
8. Migration monitoring and reconciliation should be automated rather than performed manually.

---

# Technologies

* AWS S3
* Google Cloud Storage
* Google Cloud Storage Transfer Service
* AWS IAM
* Google Cloud IAM
* Terraform
* Python
* Bash
* GitHub Actions
* Cloud Monitoring

---

# Repository Disclaimer

This repository is a **sanitized reference implementation/case study**.

Production bucket names, credentials, customer information, object names, IP addresses, account/project IDs, and other sensitive information have been removed or replaced with placeholders.
