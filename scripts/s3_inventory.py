```python
#!/usr/bin/env python3

"""
S3 Pre-Migration Inventory

Creates a deterministic inventory of objects in an S3 bucket.

Outputs:

1. CSV inventory:
   key,size,last_modified,etag,storage_class

2. JSON summary:
   object count
   total bytes
   largest object
   prefix count
   timestamp

The inventory is intended to become the baseline for
post-migration S3 -> GCS reconciliation.
"""

from __future__ import annotations

import argparse
import csv
import json
import sys
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path

import boto3
from botocore.exceptions import BotoCoreError, ClientError


def human_size(size: int) -> str:
    """Convert bytes to a human-readable size."""

    units = ["B", "KiB", "MiB", "GiB", "TiB", "PiB"]

    value = float(size)

    for unit in units:
        if value < 1024 or unit == units[-1]:
            return f"{value:.2f} {unit}"

        value /= 1024

    return f"{size} B"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate a pre-migration inventory for an S3 bucket."
    )

    parser.add_argument(
        "--bucket",
        required=True,
        help="S3 bucket name.",
    )

    parser.add_argument(
        "--output",
        required=True,
        help="CSV inventory output path.",
    )

    parser.add_argument(
        "--summary",
        required=True,
        help="JSON summary output path.",
    )

    return parser.parse_args()


def inventory_bucket(bucket: str, output_path: Path) -> dict:
    s3 = boto3.client("s3")

    output_path.parent.mkdir(parents=True, exist_ok=True)

    object_count = 0
    total_bytes = 0

    largest_object_key = ""
    largest_object_size = 0

    prefixes = set()

    storage_classes = defaultdict(int)

    inventory_timestamp = datetime.now(timezone.utc).isoformat()

    try:
        paginator = s3.get_paginator("list_objects_v2")

        with output_path.open(
            "w",
            newline="",
            encoding="utf-8",
        ) as csv_file:

            writer = csv.writer(csv_file)

            writer.writerow(
                [
                    "key",
                    "size",
                    "last_modified",
                    "etag",
                    "storage_class",
                ]
            )

            for page in paginator.paginate(Bucket=bucket):

                for obj in page.get("Contents", []):

                    key = obj["Key"]
                    size = obj["Size"]

                    object_count += 1
                    total_bytes += size

                    if size > largest_object_size:
                        largest_object_size = size
                        largest_object_key = key

                    # Capture the first path component as a
                    # simple prefix distribution metric.
                    if "/" in key:
                        prefixes.add(key.split("/", 1)[0])
                    else:
                        prefixes.add("<root>")

                    storage_class = obj.get(
                        "StorageClass",
                        "STANDARD",
                    )

                    storage_classes[storage_class] += 1

                    writer.writerow(
                        [
                            key,
                            size,
                            obj["LastModified"].isoformat(),
                            obj.get("ETag", ""),
                            storage_class,
                        ]
                    )

    except (ClientError, BotoCoreError) as exc:
        print(
            f"ERROR: Unable to inventory bucket '{bucket}': {exc}",
            file=sys.stderr,
        )
        sys.exit(1)

    return {
        "bucket": bucket,
        "inventory_timestamp": inventory_timestamp,
        "object_count": object_count,
        "total_bytes": total_bytes,
        "total_size_human": human_size(total_bytes),
        "prefix_count": len(prefixes),
        "largest_object_key": largest_object_key,
        "largest_object_size": largest_object_size,
        "largest_object_size_human": human_size(
            largest_object_size
        ),
        "storage_classes": dict(storage_classes),
    }


def main() -> None:
    args = parse_args()

    output_path = Path(args.output)
    summary_path = Path(args.summary)

    summary = inventory_bucket(
        bucket=args.bucket,
        output_path=output_path,
    )

    summary_path.parent.mkdir(
        parents=True,
        exist_ok=True,
    )

    with summary_path.open(
        "w",
        encoding="utf-8",
    ) as summary_file:

        json.dump(
            summary,
            summary_file,
            indent=2,
            sort_keys=True,
        )

    print()
    print("Inventory summary")
    print("-----------------")
    print(f"Bucket       : {summary['bucket']}")
    print(f"Objects      : {summary['object_count']:,}")
    print(f"Total bytes  : {summary['total_bytes']:,}")
    print(f"Total size   : {summary['total_size_human']}")
    print(f"Prefixes     : {summary['prefix_count']:,}")
    print(
        "Largest      : "
        f"{summary['largest_object_size_human']}"
    )
    print(f"CSV          : {output_path}")
    print(f"Summary      : {summary_path}")


if __name__ == "__main__":
    main()
```
