"""Background serial reader for Arduino environmental sensor values."""

from __future__ import annotations

import json
import logging
import os
import threading
from decimal import Decimal, InvalidOperation
from datetime import datetime, timezone
from typing import Any, Callable

from dotenv import load_dotenv

from app.db.database import SessionLocal
from app.models.sensor import SensorReading

load_dotenv()

logger = logging.getLogger(__name__)

DEFAULT_SENSOR_PORT = "/dev/ttyUSB0"
DEFAULT_SENSOR_BAUD_RATE = 9600
SERIAL_RETRY_SECONDS = 5
DEFAULT_SENSOR_SAVE_INTERVAL_SECONDS = 60


def _bool_from_env(name: str, default: bool) -> bool:
    value = os.getenv(name)
    if value is None:
        return default

    return value.strip().lower() in {"1", "true", "yes", "on"}


def _utc_now() -> datetime:
    return datetime.now(timezone.utc)


def _isoformat_z(value: datetime | None) -> str | None:
    if value is None:
        return None

    return value.astimezone(timezone.utc).isoformat().replace("+00:00", "Z")


class SensorService:
    """Reads Arduino serial data without blocking the FastAPI process."""

    def __init__(
        self,
        *,
        port: str | None = None,
        baud_rate: int | None = None,
        enabled: bool | None = None,
        premise_id: int | None = None,
        db_session_factory: Callable[[], Any] = SessionLocal,
        save_interval_seconds: int | None = None,
    ) -> None:
        self.port = port or os.getenv("SENSOR_SERIAL_PORT", DEFAULT_SENSOR_PORT)
        self.baud_rate = baud_rate or int(
            os.getenv("SENSOR_BAUD_RATE", str(DEFAULT_SENSOR_BAUD_RATE))
        )
        self.premise_id = premise_id if premise_id is not None else self._premise_id_from_env()
        self.enabled = (
            _bool_from_env("ENABLE_SENSOR_SERVICE", True)
            if enabled is None
            else enabled
        )
        self._db_session_factory = db_session_factory
        self._save_interval_seconds = (
            save_interval_seconds
            if save_interval_seconds is not None
            else self._save_interval_seconds_from_env()
        )

        self._lock = threading.Lock()
        self._thread: threading.Thread | None = None
        self._persist_thread: threading.Thread | None = None
        self._stop_event = threading.Event()
        self._last_saved_at: datetime | None = None
        self._latest: dict[str, Any] = {
            "status": "disabled" if not self.enabled else "disconnected",
            "temperature": None,
            "humidity": None,
            "gas": None,
            "last_updated": None,
        }

    def start(self) -> None:
        if not self.enabled:
            self._set_status("disabled")
            logger.info("Sensor service disabled by ENABLE_SENSOR_SERVICE=false")
            return

        if self._thread is not None and self._thread.is_alive():
            return

        self._stop_event.clear()
        self._thread = threading.Thread(
            target=self._read_loop,
            name="sensor-serial-reader",
            daemon=True,
        )
        self._thread.start()
        self._persist_thread = threading.Thread(
            target=self._persistence_loop,
            name="sensor-reading-persister",
            daemon=True,
        )
        self._persist_thread.start()
        logger.info(
            "Sensor service reader starting on %s at %s baud",
            self.port,
            self.baud_rate,
        )

    def stop(self) -> None:
        self._stop_event.set()

    def get_latest(self) -> dict[str, Any]:
        with self._lock:
            return {
                **self._latest,
                "last_updated": _isoformat_z(self._latest["last_updated"]),
            }

    def update_from_line(self, line: str) -> bool:
        parsed = self.parse_line(line)
        if parsed is None:
            logger.warning("Skipping invalid sensor serial line: %s", line)
            return False

        with self._lock:
            self._latest.update(
                {
                    "status": "connected",
                    "temperature": parsed["temperature"],
                    "humidity": parsed["humidity"],
                    "gas": parsed["gas"],
                    "last_updated": _utc_now(),
                }
            )
        return True

    @staticmethod
    def parse_line(line: str) -> dict[str, float] | None:
        stripped = line.strip()
        if not stripped:
            return None

        try:
            if stripped.startswith("{"):
                payload = json.loads(stripped)
            else:
                payload = SensorService._parse_comma_line(stripped)

            return {
                "temperature": float(payload["temperature"]),
                "humidity": float(payload["humidity"]),
                "gas": float(payload["gas"]),
            }
        except (KeyError, TypeError, ValueError, json.JSONDecodeError):
            return None

    @staticmethod
    def _parse_comma_line(line: str) -> dict[str, str]:
        payload: dict[str, str] = {}
        for part in line.split(","):
            key, separator, value = part.partition("=")
            if not separator:
                raise ValueError("Sensor comma line must use key=value pairs")
            payload[key.strip()] = value.strip()
        return payload

    @staticmethod
    def _premise_id_from_env() -> int | None:
        raw_premise_id = os.getenv("SENSOR_PREMISE_ID")
        if raw_premise_id is None or raw_premise_id.strip() == "":
            logger.warning(
                "[SENSOR] SENSOR_PREMISE_ID is not configured; persistence will be skipped"
            )
            return None

        try:
            return int(raw_premise_id)
        except ValueError:
            logger.warning(
                "[SENSOR] Invalid SENSOR_PREMISE_ID=%s; persistence will be skipped",
                raw_premise_id,
            )
            return None

    @staticmethod
    def _save_interval_seconds_from_env() -> int:
        raw_interval = os.getenv("SENSOR_SAVE_INTERVAL_SECONDS")
        if raw_interval is None or raw_interval.strip() == "":
            return DEFAULT_SENSOR_SAVE_INTERVAL_SECONDS

        try:
            interval = int(raw_interval)
            if interval <= 0:
                raise ValueError
            return interval
        except ValueError:
            logger.warning(
                "[SENSOR] Invalid SENSOR_SAVE_INTERVAL_SECONDS=%s; using default %s seconds",
                raw_interval,
                DEFAULT_SENSOR_SAVE_INTERVAL_SECONDS,
            )
            return DEFAULT_SENSOR_SAVE_INTERVAL_SECONDS

    def _set_status(self, status: str) -> None:
        with self._lock:
            self._latest["status"] = status

    def _persistence_loop(self) -> None:
        while not self._stop_event.wait(5):
            self._persist_latest_reading()

    def _persist_latest_reading(self, *, now: datetime | None = None) -> bool:
        now = now or _utc_now()

        if self._last_saved_at is not None:
            elapsed = (now - self._last_saved_at).total_seconds()
            if elapsed < self._save_interval_seconds:
                return False

        snapshot = self._latest_snapshot_for_persistence()
        if snapshot is None:
            return False

        db = self._db_session_factory()
        try:
            reading = SensorReading(
                premise_id=snapshot["premise_id"],
                temperature=snapshot["temperature"],
                humidity=snapshot["humidity"],
                gas=snapshot["gas"],
                sensor_status=snapshot["sensor_status"],
                recorded_at=now,
            )
            db.add(reading)
            db.commit()
            self._last_saved_at = now
            logger.info(
                "[SENSOR] Saved reading: temp=%s humidity=%s gas=%s premise_id=%s",
                snapshot["temperature"],
                snapshot["humidity"],
                snapshot["gas"],
                snapshot["premise_id"],
            )
            return True
        except Exception:
            db.rollback()
            logger.exception("[SENSOR] Failed to save sensor reading")
            return False
        finally:
            db.close()

    def _latest_snapshot_for_persistence(self) -> dict[str, Any] | None:
        if self.premise_id is None:
            logger.warning(
                "[SENSOR] SENSOR_PREMISE_ID is not configured; skipping persistence"
            )
            return None

        with self._lock:
            snapshot = dict(self._latest)

        if snapshot["status"] != "connected":
            return None

        if (
            snapshot["temperature"] is None
            or snapshot["humidity"] is None
            or snapshot["gas"] is None
        ):
            return None

        try:
            return {
                "premise_id": self.premise_id,
                "temperature": Decimal(str(snapshot["temperature"])),
                "humidity": Decimal(str(snapshot["humidity"])),
                "gas": int(snapshot["gas"]),
                "sensor_status": snapshot["status"],
            }
        except (InvalidOperation, TypeError, ValueError):
            logger.warning("[SENSOR] Latest sensor values are invalid; skipping persistence")
            return None

    def _read_loop(self) -> None:
        while not self._stop_event.is_set():
            try:
                import serial
            except ImportError:
                self._set_status("disconnected")
                logger.warning(
                    "pyserial is not installed; sensor service cannot read %s",
                    self.port,
                )
                self._stop_event.wait(SERIAL_RETRY_SECONDS)
                continue

            try:
                with serial.Serial(self.port, self.baud_rate, timeout=1) as arduino:
                    self._set_status("connected")
                    logger.info("Sensor serial device connected: %s", self.port)

                    while not self._stop_event.is_set():
                        raw_line = arduino.readline()
                        if not raw_line:
                            continue

                        try:
                            line = raw_line.decode("utf-8", errors="replace")
                        except AttributeError:
                            line = str(raw_line)

                        self.update_from_line(line)
            except Exception as exc:  # pragma: no cover - hardware-specific path
                self._set_status("disconnected")
                logger.warning(
                    "Sensor serial device unavailable on %s: %s",
                    self.port,
                    exc,
                )
                self._stop_event.wait(SERIAL_RETRY_SECONDS)


sensor_service = SensorService()
