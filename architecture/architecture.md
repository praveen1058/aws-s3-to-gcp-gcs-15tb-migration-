# Architecture

## Overview

This project demonstrates a production-grade migration of approximately **15 TB of object data from Amazon S3 to Google Cloud Storage**.

The architecture is designed around four primary objectives:

1. Secure cross-cloud data transfer
2. Minimal production disruption
3. Automated data integrity validation
4. Safe application cutover with rollback capability

The migration uses **Google Cloud Storage Transfer Service** as the managed transfer layer rather than running a custom transfer process on a VM.

---

## High-Level Architecture

```text
                         AWS
                  ┌─────────────────┐
                  │   Production    │
                  │   Application   │
                  └────────┬────────┘
                           │
                           ▼
                  ┌─────────────────┐
                  │    AWS S3       │
                  │                 │
                  │    ~15 TB       │
                  └────────┬────────┘
                           │
                           │ Cross-cloud transfer
                           │
                           ▼
              ┌──────────────────────────┐
              │ Google Cloud Storage     │
              │ Transfer Service        │
              │                          │
              │ • Initial migration     │
              │ • Incremental sync      │
              │ • Retry handling        │
              │ • Transfer monitoring   │
              └────────────┬─────────────┘
                           │
                           ▼
                  ┌─────────────────┐
                  │ Google Cloud    │
                  │ Storage Bucket  │
                  │                 │
                  │    ~15 TB       │
                  └────────┬────────┘
                           │
                           ▼
                  ┌─────────────────┐
                  │ Data Validation │
                  │ & Reconciliation│
                  │                 │
                  │ Object count    │
                  │ Total bytes     │
                  │ Object size     │
                  │ Checksums       │
                  └────────┬────────┘
                           │
                           ▼
                  ┌─────────────────┐
                  │ Cutover /       │
                  │ Application     │
                  │ Validation      │
                  └─────────────────┘
```

---

# 1. Source Environment

The source environment is AWS.

### Source

```text
AWS S3
 └── Production Bucket
      ├── application/
      ├── images/
      ├── documents/
      ├── archive/
      └── other prefixes
```

Approximate migration volume:

```text
Data volume: ~15 TB
Source:       Amazon S3
Environment:  Production
```

The source bucket remains available throughout the migration and is not deleted immediately after transfer.

This provides a rollback path if application validation fails after cutover.

---

# 2. Transfer Layer

Google Cloud Storage Transfer Service is used as the managed cross-cloud transfer mechanism.

### Responsibilities

* Read objects from AWS S3
* Transfer objects to Google Cloud Storage
* Handle transient transfer failures
* Retry failed operations
* Provide transfer progress and status
* Perform transfer integrity checks
* Support incremental synchronization

The migration is divided into:

```text
Initial Transfer
       │
       ▼
Incremental Synchronization
       │
       ▼
Final Synchronization
       │
       ▼
Production Cutover
```

---

# 3. Destination Environment

The destination is a Google Cloud Storage bucket.

```text
GCP
└── Cloud Storage
     └── Production Bucket
          ├── application/
          ├── images/
          ├── documents/
          ├── archive/
          └── other prefixes
```

The destination bucket is provisioned with infrastructure-as-code where applicable.

Security configuration includes:

* IAM-based access control
* Encryption at rest
* Restricted administrative access
* Audit logging
* No public access unless explicitly required
* Versioning/retention configuration based on application requirements

---

# 4. Data Validation

Data validation is a separate architectural component rather than relying solely on the transfer job status.

The validation process compares the source and destination.

## Validation dimensions

### Object count

```text
S3 object count
       ==
GCS object count
```

Expected:

```text
Difference = 0
```

### Total bytes

```text
S3 total bytes
       ==
GCS total bytes
```

Expected:

```text
Difference = 0
```

### Object-level validation

For each object where applicable:

```text
Object name
Object size
Checksum
```

are compared.

Expected result:

```text
Missing objects       = 0
Extra objects         = 0
Size mismatches       = 0
Checksum mismatches   = 0
```

---

# 5. Migration Phases

## Phase 1 — Discovery

Collect source inventory information:

* Object count
* Total bytes
* Prefix distribution
* Object size distribution
* Encryption configuration
* Storage classes
* Versioning requirements
* Application read/write patterns

This establishes the migration baseline.

---

## Phase 2 — Initial Transfer

The majority of the 15 TB is transferred from S3 to GCS.

```text
AWS S3
   │
   │ Initial transfer
   ▼
Storage Transfer Service
   │
   ▼
GCS
```

The production application can continue operating according to the migration's write-consistency strategy.

---

## Phase 3 — Validation

After the initial transfer:

```text
Source Inventory
       │
       ├── Object count
       ├── Total bytes
       ├── Object size
       └── Checksums
              │
              ▼
          Compare
              │
              ▼
Destination Inventory
```

Any mismatch is investigated before proceeding to cutover.

---

## Phase 4 — Incremental Synchronization

If the source bucket continues to receive writes during the migration, an incremental synchronization is performed.

```text
Initial transfer
       │
       ▼
New/changed S3 objects
       │
       ▼
Incremental transfer
       │
       ▼
GCS
```

This reduces the amount of data that must be handled during the final cutover window.

---

## Phase 5 — Final Cutover

The production cutover follows a controlled sequence:

```text
1. Stop/quiesce application writes
             │
             ▼
2. Run final synchronization
             │
             ▼
3. Run final validation
             │
             ▼
4. Verify migration acceptance criteria
             │
             ▼
5. Change application configuration
             │
             ▼
6. Application smoke testing
             │
             ▼
7. Monitor production
```

---

# 6. Rollback Architecture

The AWS S3 bucket is retained during the defined rollback period.

```text
                  ┌─────────────┐
                  │ Application │
                  └──────┬──────┘
                         │
                    Production
                     traffic
                         │
                         ▼
                  ┌─────────────┐
                  │     GCS     │
                  └─────────────┘

                         │
                    If failure
                         │
                         ▼

                  ┌─────────────┐
                  │    AWS S3   │
                  │   Rollback  │
                  │    Source   │
                  └─────────────┘
```

Rollback can be initiated if:

* Required objects are missing
* Application reads fail
* IAM permissions are incorrect
* Performance is unacceptable
* Business validation fails
* Data integrity validation fails

The source is not deleted until the rollback window has expired and the migration has been formally accepted.

---

# 7. Security Architecture

Security follows the principle of least privilege.

```text
AWS Migration Identity
        │
        ├── List S3 bucket
        └── Read S3 objects

GCP Transfer Identity
        │
        └── Write required GCS objects
```

No long-lived credentials are stored in GitHub.

Sensitive values such as:

* AWS credentials
* GCP service-account keys
* Account IDs
* Project IDs
* Production bucket names

are excluded from source control.

---

# 8. Observability

Migration observability covers:

* Transfer progress
* Objects transferred
* Bytes transferred
* Failed objects
* Retry activity
* Transfer throughput
* Remaining data
* Validation status

The objective is to identify migration problems before production cutover.

---

# 9. Failure Handling

| Failure                           | Response                         |
| --------------------------------- | -------------------------------- |
| S3 permission failure             | Validate AWS IAM                 |
| GCS permission failure            | Validate GCP IAM                 |
| Transient API failure             | Retry                            |
| Individual object failure         | Reprocess/retry affected objects |
| Object count mismatch             | Stop cutover and investigate     |
| Byte mismatch                     | Reconcile inventories            |
| Checksum mismatch                 | Re-transfer affected objects     |
| Application failure after cutover | Roll back                        |
| Validation failure                | Do not complete migration        |

---

# 10. Design Principles

### Managed services over custom infrastructure

Use Storage Transfer Service rather than maintaining custom transfer workers where possible.

### Validate independently

Do not treat a successful transfer job as the only indication that migration is complete.

### Minimize the cutover window

Perform the bulk migration before the production cutover and use incremental synchronization for late changes.

### Preserve rollback

Keep the source available until the migration is formally accepted.

### Automate reconciliation

Object count, byte count, and object-level comparison should be automated rather than manually verified.

### Least privilege

Migration identities receive only the permissions required to perform the migration.

---

# 11. Migration Acceptance Criteria

The migration is considered successful only when all required checks pass.

```text
[PASS] Initial transfer completed
[PASS] Failed objects = 0
[PASS] Object count matches
[PASS] Total bytes match
[PASS] Missing objects = 0
[PASS] Extra objects = 0
[PASS] Size mismatches = 0
[PASS] Checksum mismatches = 0
[PASS] Final synchronization completed
[PASS] Application smoke tests passed
[PASS] Monitoring operational
[PASS] Rollback plan verified
```

---

# 12. Repository Mapping

The architecture maps to the repository as follows:

```text
architecture/
    architecture.png
    architecture.md

terraform/
    aws/
    gcp/

scripts/
    pre_migration_inventory.sh
    create_transfer_job.sh
    post_migration_validation.sh
    compare_inventory.py
    generate_report.py

docs/
    migration-plan.md
    security.md
    rollback-plan.md
    monitoring.md
    performance.md
    cost-analysis.md

tests/
    test_validation.py
```

This separation keeps infrastructure, migration automation, validation, and operational documentation independently maintainable.
