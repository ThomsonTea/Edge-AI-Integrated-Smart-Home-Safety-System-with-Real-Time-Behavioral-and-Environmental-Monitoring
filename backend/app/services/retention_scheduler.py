"""Single-runner background scheduling for daily retention cleanup."""

import os
import threading

from sqlalchemy import text

from app.db.database import SessionLocal
from app.services.data_retention_service import cleanup_all_premises


LOCK_ID = 739_214_681
DEFAULT_INTERVAL_SECONDS = 24 * 60 * 60


class RetentionScheduler:
    def __init__(self) -> None:
        self._stop_event = threading.Event()
        self._thread: threading.Thread | None = None

    def start(self) -> None:
        enabled = os.getenv("RETENTION_CLEANUP_ENABLED", "true").strip().lower()
        if enabled not in {"1", "true", "yes", "on"} or self._thread is not None:
            return

        self._thread = threading.Thread(
            target=self._run,
            name="retention-cleanup",
            daemon=True,
        )
        self._thread.start()

    def stop(self) -> None:
        self._stop_event.set()
        if self._thread is not None:
            self._thread.join(timeout=5)
            self._thread = None

    def _run(self) -> None:
        try:
            interval = max(60, int(os.getenv("RETENTION_CLEANUP_INTERVAL_SECONDS", DEFAULT_INTERVAL_SECONDS)))
        except ValueError:
            interval = DEFAULT_INTERVAL_SECONDS

        while not self._stop_event.is_set():
            self.run_once()
            if self._stop_event.wait(interval):
                break

    def run_once(self) -> None:
        db = SessionLocal()
        lock_acquired = False
        try:
            lock_acquired = bool(
                db.execute(text("SELECT pg_try_advisory_lock(:lock_id)"), {"lock_id": LOCK_ID}).scalar()
            )
            if not lock_acquired:
                return

            result = cleanup_all_premises(db)
            print(f"Retention cleanup completed: {result.to_dict()}")
        except Exception as exc:
            db.rollback()
            print(f"Retention cleanup failed: {exc}")
        finally:
            if lock_acquired:
                try:
                    db.execute(text("SELECT pg_advisory_unlock(:lock_id)"), {"lock_id": LOCK_ID})
                except Exception as exc:
                    print(f"Retention cleanup lock release failed: {exc}")
            db.close()


retention_scheduler = RetentionScheduler()
