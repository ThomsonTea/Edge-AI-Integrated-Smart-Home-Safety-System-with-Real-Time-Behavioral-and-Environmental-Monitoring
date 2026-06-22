"""Protected analytics endpoints for sensor trends and security events."""

from datetime import datetime, time, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.db.database import get_db
from app.middleware import get_current_user
from app.models.event import AIEvent
from app.models.profile import Profile
from app.models.sensor import SensorReading

router = APIRouter()

SUPPORTED_RANGES = {
    "24h": timedelta(hours=24),
    "7d": timedelta(days=7),
    "30d": timedelta(days=30),
}

ANALYTICS_EVENT_TYPES = [
    "known_person",
    "unknown_person",
    "fall_detected",
    "prolonged_inactivity",
    "gas_alert",
    "high_temperature",
    "sensor_offline",
]


def _range_start(range_value: str) -> datetime:
    try:
        delta = SUPPORTED_RANGES[range_value]
    except KeyError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Unsupported analytics range",
        )

    return datetime.now(timezone.utc) - delta


def _current_profile(current_user: dict, db: Session) -> Profile:
    user_id = current_user.get("user_id")
    profile = db.query(Profile).filter(Profile.id == user_id).first()

    if profile is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User profile not found",
        )

    return profile


def _empty_event_counts() -> list[dict]:
    return [
        {
            "event_type": event_type,
            "count": 0,
        }
        for event_type in ANALYTICS_EVENT_TYPES
    ]


def _bucket_kind(range_value: str) -> str:
    return "hourly" if range_value == "24h" else "daily"


def _bucket_start(value: datetime, bucket: str) -> datetime:
    value = value.astimezone(timezone.utc)
    if bucket == "hourly":
        return value.replace(minute=0, second=0, microsecond=0)

    return datetime.combine(value.date(), time.min, tzinfo=timezone.utc)


def _bucket_label(value: datetime, bucket: str) -> str:
    if bucket == "hourly":
        return value.strftime("%H:00")

    return value.strftime("%a")


def _event_trend_buckets(
    *,
    range_value: str,
    now: datetime | None = None,
) -> list[dict]:
    now = now or datetime.now(timezone.utc)
    bucket = _bucket_kind(range_value)

    if bucket == "hourly":
        current = _bucket_start(now - timedelta(hours=23), bucket)
        bucket_count = 24
        step = timedelta(hours=1)
    else:
        days = 7 if range_value == "7d" else 30
        current = _bucket_start(now - timedelta(days=days - 1), bucket)
        bucket_count = days
        step = timedelta(days=1)

    buckets = []
    for _ in range(bucket_count):
        buckets.append(
            {
                "label": _bucket_label(current, bucket),
                "timestamp": current,
                **{event_type: 0 for event_type in ANALYTICS_EVENT_TYPES},
            }
        )
        current += step

    return buckets


def _event_trend_response(
    *,
    range_value: str,
    events: list[AIEvent],
    now: datetime | None = None,
) -> dict:
    bucket = _bucket_kind(range_value)
    buckets = _event_trend_buckets(range_value=range_value, now=now)
    bucket_by_start = {item["timestamp"]: item for item in buckets}

    for event in events:
        if event.timestamp is None or event.event_type not in ANALYTICS_EVENT_TYPES:
            continue

        started_at = _bucket_start(event.timestamp, bucket)
        if started_at not in bucket_by_start:
            continue

        bucket_item = bucket_by_start[started_at]
        bucket_item[event.event_type] += 1

    return {
        "range": range_value,
        "bucket": bucket,
        "points": buckets,
    }


@router.get("/sensors")
def get_sensor_analytics(
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
    range: str = Query(default="24h"),
):
    start_at = _range_start(range)
    profile = _current_profile(current_user, db)

    if profile.premise_id is None:
        return {"range": range, "points": []}

    readings = (
        db.query(SensorReading)
        .filter(
            SensorReading.premise_id == profile.premise_id,
            SensorReading.recorded_at >= start_at,
        )
        .order_by(SensorReading.recorded_at.asc())
        .all()
    )

    return {
        "range": range,
        "points": [
            {
                "timestamp": reading.recorded_at,
                "temperature": (
                    float(reading.temperature)
                    if reading.temperature is not None
                    else None
                ),
                "humidity": (
                    float(reading.humidity)
                    if reading.humidity is not None
                    else None
                ),
                "gas": reading.gas,
            }
            for reading in readings
        ],
    }


@router.get("/events")
def get_event_analytics(
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
    range: str = Query(default="7d"),
):
    start_at = _range_start(range)
    profile = _current_profile(current_user, db)

    if profile.premise_id is None:
        return {"range": range, "counts": _empty_event_counts()}

    rows = (
        db.query(AIEvent.event_type, func.count(AIEvent.id))
        .filter(
            AIEvent.premise_id == profile.premise_id,
            AIEvent.timestamp >= start_at,
            AIEvent.event_type.in_(ANALYTICS_EVENT_TYPES),
        )
        .group_by(AIEvent.event_type)
        .all()
    )
    counts = {event_type: int(count) for event_type, count in rows}

    return {
        "range": range,
        "counts": [
            {
                "event_type": event_type,
                "count": counts.get(event_type, 0),
            }
            for event_type in ANALYTICS_EVENT_TYPES
        ],
    }


@router.get("/event-trends")
def get_event_trend_analytics(
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
    range: str = Query(default="7d"),
):
    start_at = _range_start(range)
    profile = _current_profile(current_user, db)

    if profile.premise_id is None:
        return _event_trend_response(range_value=range, events=[])

    events = (
        db.query(AIEvent)
        .filter(
            AIEvent.premise_id == profile.premise_id,
            AIEvent.timestamp >= start_at,
            AIEvent.event_type.in_(ANALYTICS_EVENT_TYPES),
        )
        .order_by(AIEvent.timestamp.asc())
        .all()
    )

    return _event_trend_response(range_value=range, events=events)
