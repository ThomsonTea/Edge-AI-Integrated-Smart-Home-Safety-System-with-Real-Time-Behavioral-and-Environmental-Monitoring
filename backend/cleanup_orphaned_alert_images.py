"""Audit or delete alert images that are not referenced by any AI event."""

import argparse

from app.db.database import SessionLocal
from app.services.data_retention_service import (
    ALERT_STORAGE_DIR,
    delete_orphaned_alert_images,
    find_orphaned_alert_images,
)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--delete",
        action="store_true",
        help="Delete the orphaned files. Without this flag, only list them.",
    )
    args = parser.parse_args()

    db = SessionLocal()
    try:
        orphaned = find_orphaned_alert_images(db)
        total_bytes = sum(path.stat().st_size for path in orphaned)

        print(f"Alert storage: {ALERT_STORAGE_DIR}")
        print(f"Orphaned images: {len(orphaned)} ({total_bytes} bytes)")
        for path in orphaned:
            print(path.relative_to(ALERT_STORAGE_DIR))

        if not args.delete:
            print("Dry run only; no files were deleted.")
            return 0

        deleted, failures = delete_orphaned_alert_images(db)
        print(f"Deleted images: {len(deleted)}")
        print(f"Delete failures: {len(failures)}")
        return 1 if failures else 0
    finally:
        db.close()


if __name__ == "__main__":
    raise SystemExit(main())
