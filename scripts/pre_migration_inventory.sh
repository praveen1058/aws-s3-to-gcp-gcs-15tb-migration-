```bash
#!/usr/bin/env bash

set -euo pipefail

# ============================================================
# AWS S3 Pre-Migration Inventory
#
# Purpose:
#   Establish a reproducible baseline of the source S3 bucket
#   before migration to Google Cloud Storage.
#
# Usage:
#   ./scripts/pre_migration_inventory.sh \
#       <bucket-name> \
#       [output-directory]
#
# Example:
#   ./scripts/pre_migration_inventory.sh \
#       my-production-bucket \
#       reports/pre-migration
# ============================================================

BUCKET_NAME="${1:-}"
OUTPUT_DIR="${2:-reports/pre-migration}"

if [[ -z "${BUCKET_NAME}" ]]; then
    echo "ERROR: S3 bucket name is required."
    echo
    echo "Usage:"
    echo "  $0 <bucket-name> [output-directory]"
    exit 1
fi

command -v aws >/dev/null 2>&1 || {
    echo "ERROR: AWS CLI is not installed."
    exit 1
}

command -v python3 >/dev/null 2>&1 || {
    echo "ERROR: Python 3 is not installed."
    exit 1
}

mkdir -p "${OUTPUT_DIR}"

TIMESTAMP="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

INVENTORY_FILE="${OUTPUT_DIR}/s3_inventory.csv"
SUMMARY_FILE="${OUTPUT_DIR}/s3_summary.json"
REPORT_FILE="${OUTPUT_DIR}/s3_report.txt"

echo "============================================================"
echo " AWS S3 PRE-MIGRATION INVENTORY"
echo "============================================================"
echo
echo "Bucket      : ${BUCKET_NAME}"
echo "Started UTC : ${TIMESTAMP}"
echo "Output      : ${OUTPUT_DIR}"
echo

echo "[1/4] Validating AWS credentials..."

aws sts get-caller-identity >/dev/null

echo "      AWS credentials: OK"
echo

echo "[2/4] Validating S3 bucket access..."

aws s3api head-bucket \
    --bucket "${BUCKET_NAME}"

echo "      Bucket access: OK"
echo

echo "[3/4] Generating object inventory..."

python3 scripts/s3_inventory.py \
    --bucket "${BUCKET_NAME}" \
    --output "${INVENTORY_FILE}" \
    --summary "${SUMMARY_FILE}"

echo
echo "[4/4] Generating human-readable report..."

python3 - "${SUMMARY_FILE}" "${REPORT_FILE}" <<'PY'
import json
import sys
from pathlib import Path

summary_file = Path(sys.argv[1])
report_file = Path(sys.argv[2])

with summary_file.open() as f:
    data = json.load(f)

report = f"""
============================================================
 AWS S3 PRE-MIGRATION REPORT
============================================================

Bucket:
  {data["bucket"]}

Inventory timestamp:
  {data["inventory_timestamp"]}

Objects:
  {data["object_count"]:,}

Total bytes:
  {data["total_bytes"]:,}

Total size:
  {data["total_size_human"]}

Prefixes:
  {data["prefix_count"]:,}

Largest object:
  {data["largest_object_key"]}
  {data["largest_object_size_human"]}

============================================================
 STATUS: BASELINE CREATED
============================================================
"""

report_file.write_text(report.strip() + "\n")

print(report.strip())
PY

echo
echo "Inventory completed successfully."
echo
echo "Files generated:"
echo "  ${INVENTORY_FILE}"
echo "  ${SUMMARY_FILE}"
echo "  ${REPORT_FILE}"
echo
```
