"""Retention cleanup for AI events, alert images, and sensor readings."""

from dataclasses import asdict, dataclass
from datetime import datetime, timedelta, timezone
from pathlib import Path
from urllib.parse import unquote, urlsplit

from sqlalchemy.orm import Session

from app.models.device import Device
from app.models.event import AIEvent
from app.models.profile import PremiseSetting
from app.models.sensor import Sensor, SensorReading


BACKEND_DIR = Path(__file__).resolve().parents[2]
ALERT_STORAGE_DIR = (BACKEND_DIR / "storage" / "alerts").resolve()
DEFAULT_BATCH_SIZE = 500


@dataclass
class CleanupResult:
    events_deleted: int = 0
    sensor_readings_deleted: int = 0
    images_deleted: int = 0
    image_references_cleared: int = 0
    image_delete_failures: int = 0

    def to_dict(self) -> dict[str, int]:
        return asdict(self)

    def add(self, other: "CleanupResult") -> None:
        for field_name in self.__dataclass_fields__:
            setattr(self, field_name, getattr(self, field_name) + getattr(other, field_name))


def _local_alert_path(image_path: str | None) -> Path | None:
    """Resolve an API image reference only when it is inside storage/alerts."""
    if not image_path:
        return None

    parsed_path = unquote(urlsplit(image_path).path).replace("\\", "/")
    marker = "/storage/alerts/"
    if marker in parsed_path:
        relative_path = parsed_path.split(marker, 1)[1]
    elif parsed_path.startswith("storage/alerts/"):
        relative_path = parsed_path[len("storage/alerts/") :]
    else:
        candidate = Path(image_path)
        if not candidate.is_absolute():
            return None
        try:
            candidate.resolve().relative_to(ALERT_STORAGE_DIR)
        except (OSError, ValueError):
            return None
        return candidate.resolve()

    candidate = (ALERT_STORAGE_DIR / relative_path).resolve()
    try:
        candidate.relative_to(ALERT_STORAGE_DIR)
    except ValueError:
        return None
    return candidate


def _delete_unreferenced_images(db: Session, image_paths: set[str]) -> tuple[int, int]:
    deleted = 0
    failures = 0
    for image_path in image_paths:
        still_referenced = db.query(AIEvent.id).filter(AIEvent.image_path == image_path).first()
        if still_referenced is not None:
            continue

        local_path = _local_alert_path(image_path)
        if local_path is None:
            continue

        try:
            if local_path.exists():
                local_path.unlink()
                deleted += 1
        except OSError as exc:
            failures += 1
            print(f"Retention cleanup could not delete image {local_path}: {exc}")
    return deleted, failures


def cleanup_premise_data(
    db: Session,
    settings: PremiseSetting,
    *,
    now: datetime | None = None,
    batch_size: int = DEFAULT_BATCH_SIZE,
) -> CleanupResult:
    """Delete expired data for one premise in bounded transactions."""
    if batch_size < 1:
        raise ValueError("batch_size must be at least 1")

    current_time = now or datetime.now(timezone.utc)
    result = CleanupResult()
    event_cutoff = current_time - timedelta(days=settings.event_retention_days)

    while True:
        query = db.query(AIEvent).filter(
            AIEvent.premise_id == settings.premise_id,
            AIEvent.timestamp < event_cutoff,
            AIEvent.is_pinned.is_(False),
        )
        if settings.preserve_unacknowledged:
            query = query.filter(AIEvent.is_acknowledged.is_(True))
        if settings.preserve_critical:
            query = query.filter(AIEvent.severity != "critical")

        events = query.order_by(AIEvent.id).limit(batch_size).all()
        if not events:
            break

        image_paths = {event.image_path for event in events if event.image_path}
        for event in events:
            db.delete(event)
        db.commit()
        result.events_deleted += len(events)

        deleted, failures = _delete_unreferenced_images(db, image_paths)
        result.images_deleted += deleted
        result.image_delete_failures += failures

    if settings.auto_delete_images:
        image_cutoff = current_time - timedelta(days=settings.image_retention_days)
        while True:
            image_query = db.query(AIEvent).filter(
                AIEvent.premise_id == settings.premise_id,
                AIEvent.timestamp < image_cutoff,
                AIEvent.image_path.isnot(None),
                AIEvent.is_pinned.is_(False),
            )
            if settings.preserve_unacknowledged:
                image_query = image_query.filter(AIEvent.is_acknowledged.is_(True))
            if settings.preserve_critical:
                image_query = image_query.filter(AIEvent.severity != "critical")
            events = image_query.order_by(AIEvent.id).limit(batch_size).all()
            if not events:
                break

            image_paths = {event.image_path for event in events if event.image_path}
            for event in events:
                event.image_path = None
            db.commit()
            result.image_references_cleared += len(events)

            deleted, failures = _delete_unreferenced_images(db, image_paths)
            result.images_deleted += deleted
            result.image_delete_failures += failures

    sensor_cutoff = current_time - timedelta(days=settings.sensor_retention_days)
    while True:
        readings = (
            db.query(SensorReading)
            .join(Sensor, SensorReading.sensor_id == Sensor.device_id)
            .join(Device, Sensor.device_id == Device.id)
            .filter(
                Device.premise_id == settings.premise_id,
                SensorReading.recorded_at < sensor_cutoff,
            )
            .order_by(SensorReading.id)
            .limit(batch_size)
            .all()
        )
        if not readings:
            break

        for reading in readings:
            db.delete(reading)
        db.commit()
        result.sensor_readings_deleted += len(readings)

    return result


def cleanup_all_premises(db: Session, *, now: datetime | None = None) -> CleanupResult:
    total = CleanupResult()
    for settings in db.query(PremiseSetting).all():
        total.add(cleanup_premise_data(db, settings, now=now))
    return total
