"""Protected dashboard summary endpoint."""

from datetime import datetime, time, timedelta, timezone
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.db.database import get_db
from app.middleware import get_current_user
from app.models.event import AIEvent
from app.models.profile import Profile

router = APIRouter()

TIME_FILTERS = {"today", "yesterday", "last_7_days", "all"}
EVENT_TYPE_FILTERS = {
    "known_person",
    "unknown_person",
    "blacklisted_person",
    "fire_alert",
    "gas_alert",
    "system_error",
}
CRITICAL_EVENT_TYPES = {
    "unknown_person",
    "blacklisted_person",
    "fire_alert",
    "gas_alert",
    "system_error",
    "camera_offline",
}


def _get_current_profile(current_user: dict, db: Session) -> Profile:
    user_id = current_user.get("user_id")
    user = db.query(Profile).filter(Profile.id == user_id).first()

    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User profile not found",
        )

    return user


def _time_window(time_filter: str) -> tuple[Optional[datetime], Optional[datetime]]:
    now = datetime.now(timezone.utc)
    today_start = datetime.combine(now.date(), time.min, tzinfo=timezone.utc)

    if time_filter == "today":
        return today_start, None

    if time_filter == "yesterday":
        yesterday_start = today_start - timedelta(days=1)
        return yesterday_start, today_start

    if time_filter == "last_7_days":
        return today_start - timedelta(days=6), None

    return None, None


def _today_window() -> tuple[datetime, datetime]:
    now = datetime.now(timezone.utc)
    start = datetime.combine(now.date(), time.min, tzinfo=timezone.utc)
    return start, start + timedelta(days=1)


def _event_to_response(event: AIEvent | None) -> Optional[dict]:
    if event is None:
        return None

    return {
        "id": event.id,
        "event_type": event.event_type,
        "timestamp": event.timestamp,
        "confidence_score": (
            float(event.confidence_score)
            if event.confidence_score is not None
            else None
        ),
        "image_path": event.image_path,
        "is_acknowledged": bool(event.is_acknowledged),
        "premise_id": event.premise_id,
        "profile_id": event.profile_id,
    }


def _base_event_query(
    db: Session,
    premise_id: int,
    *,
    start_date: datetime | None = None,
    end_date: datetime | None = None,
    event_type: str | None = None,
):
    query = db.query(AIEvent).filter(AIEvent.premise_id == premise_id)

    if start_date is not None:
        query = query.filter(AIEvent.timestamp >= start_date)

    if end_date is not None:
        query = query.filter(AIEvent.timestamp < end_date)

    if event_type is not None:
        query = query.filter(AIEvent.event_type == event_type)

    return query


def _event_trend(events: list[AIEvent], time_filter: str) -> list[dict]:
    buckets: dict[str, int] = {}

    for event in events:
        timestamp = event.timestamp
        if timestamp is None:
            continue

        label = timestamp.date().isoformat()
        buckets[label] = buckets.get(label, 0) + 1

    if time_filter == "today":
        label = datetime.now(timezone.utc).date().isoformat()
        return [{"label": label, "count": buckets.get(label, 0)}]

    if time_filter == "yesterday":
        label = (datetime.now(timezone.utc).date() - timedelta(days=1)).isoformat()
        return [{"label": label, "count": buckets.get(label, 0)}]

    if time_filter == "last_7_days":
        today = datetime.now(timezone.utc).date()
        return [
            {
                "label": (today - timedelta(days=offset)).isoformat(),
                "count": buckets.get((today - timedelta(days=offset)).isoformat(), 0),
            }
            for offset in range(6, -1, -1)
        ]

    return [
        {"label": label, "count": count}
        for label, count in sorted(buckets.items())
    ]


def _event_type_counts(events: list[AIEvent]) -> dict:
    counts = {
        "known_person": 0,
        "unknown_person": 0,
        "blacklisted_person": 0,
        "other": 0,
    }

    for event in events:
        if event.event_type in counts and event.event_type != "other":
            counts[event.event_type] += 1
        else:
            counts["other"] += 1

    return counts


def _camera_status(events: list[AIEvent]) -> str:
    if events and events[0].event_type == "camera_offline":
        return "offline"

    return "online"


def _system_status(
    *,
    camera_status: str,
    unacknowledged_count: int,
    latest_critical_event: AIEvent | None,
) -> str:
    if camera_status == "offline":
        return "camera_offline"

    if latest_critical_event is not None and not latest_critical_event.is_acknowledged:
        return "critical_alert"

    if unacknowledged_count > 0:
        return "attention_required"

    return "normal"


@router.get("/summary")
def get_dashboard_summary(
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
    time_filter: str = Query(default="today"),
    event_type: str = Query(default="all"),
):
    selected_time_filter = time_filter.strip().lower()
    selected_event_type = event_type.strip().lower()

    if selected_time_filter not in TIME_FILTERS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Unsupported time filter",
        )

    if selected_event_type != "all" and selected_event_type not in EVENT_TYPE_FILTERS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Unsupported event type filter",
        )

    user = _get_current_profile(current_user=current_user, db=db)

    if user.premise_id is None:
        return {
            "system_status": "no_premise",
            "camera_status": "unknown",
            "known_person_today_count": 0,
            "unknown_person_today_count": 0,
            "unacknowledged_count": 0,
            "event_trend": [],
            "event_type_counts": {
                "known_person": 0,
                "unknown_person": 0,
                "blacklisted_person": 0,
                "other": 0,
            },
            "latest_critical_event": None,
        }

    start_date, end_date = _time_window(selected_time_filter)
    filtered_event_type = (
        None if selected_event_type == "all" else selected_event_type
    )

    filtered_events = (
        _base_event_query(
            db,
            user.premise_id,
            start_date=start_date,
            end_date=end_date,
            event_type=filtered_event_type,
        )
        .order_by(AIEvent.timestamp.desc())
        .all()
    )

    today_start, tomorrow_start = _today_window()
    known_today_count = (
        _base_event_query(
            db,
            user.premise_id,
            start_date=today_start,
            end_date=tomorrow_start,
            event_type="known_person",
        )
        .count()
    )
    unknown_today_count = (
        _base_event_query(
            db,
            user.premise_id,
            start_date=today_start,
            end_date=tomorrow_start,
            event_type="unknown_person",
        )
        .count()
    )
    unacknowledged_count = (
        db.query(AIEvent)
        .filter(
            AIEvent.premise_id == user.premise_id,
            AIEvent.is_acknowledged == False,  # noqa: E712
        )
        .count()
    )

    latest_any_event = (
        db.query(AIEvent)
        .filter(AIEvent.premise_id == user.premise_id)
        .order_by(AIEvent.timestamp.desc())
        .first()
    )
    latest_critical_event = (
        db.query(AIEvent)
        .filter(
            AIEvent.premise_id == user.premise_id,
            AIEvent.event_type.in_(CRITICAL_EVENT_TYPES),
        )
        .order_by(AIEvent.timestamp.desc())
        .first()
    )
    camera_status = _camera_status([latest_any_event] if latest_any_event else [])
    system_status = _system_status(
        camera_status=camera_status,
        unacknowledged_count=unacknowledged_count,
        latest_critical_event=latest_critical_event,
    )

    return {
        "system_status": system_status,
        "camera_status": camera_status,
        "known_person_today_count": known_today_count,
        "unknown_person_today_count": unknown_today_count,
        "unacknowledged_count": unacknowledged_count,
        "event_trend": _event_trend(filtered_events, selected_time_filter),
        "event_type_counts": _event_type_counts(filtered_events),
        "latest_critical_event": _event_to_response(latest_critical_event),
    }
