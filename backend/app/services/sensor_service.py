"""Background serial reader for Arduino environmental sensor values."""

from __future__ import annotations

import json
import logging
import os
import threading
import time
from datetime import datetime, timezone
from typing import Any

from dotenv import load_dotenv

load_dotenv()

logger = logging.getLogger(__name__)

DEFAULT_SENSOR_PORT = "/dev/ttyUSB0"
DEFAULT_SENSOR_BAUD_RATE = 9600
SERIAL_RETRY_SECONDS = 5


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
    ) -> None:
        self.port = port or os.getenv("SENSOR_SERIAL_PORT", DEFAULT_SENSOR_PORT)
        self.baud_rate = baud_rate or int(
            os.getenv("SENSOR_BAUD_RATE", str(DEFAULT_SENSOR_BAUD_RATE))
        )
        self.enabled = (
            _bool_from_env("ENABLE_SENSOR_SERVICE", True)
            if enabled is None
            else enabled
        )

        self._lock = threading.Lock()
        self._thread: threading.Thread | None = None
        self._stop_event = threading.Event()
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

    def _set_status(self, status: str) -> None:
        with self._lock:
            self._latest["status"] = status

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
