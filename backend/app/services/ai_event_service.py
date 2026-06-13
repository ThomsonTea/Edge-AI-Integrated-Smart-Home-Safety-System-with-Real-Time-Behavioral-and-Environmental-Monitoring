from decimal import Decimal
from typing import Any

from sqlalchemy.orm import Session

from app.models.event import AIEvent
from app.services.notification_service import broadcast_ai_event_once


def create_ai_event(
    db: Session,
    *,
    premise_id: int,
    event_type: str,
    confidence_score: float | Decimal | None,
    image_path: str | None,
    profile_id: int | None = None,
    is_acknowledged: bool = False,
) -> AIEvent:
    event = AIEvent(
        premise_id=premise_id,
        profile_id=profile_id,
        event_type=event_type,
        confidence_score=confidence_score,
        image_path=image_path,
        is_acknowledged=is_acknowledged,
    )

    db.add(event)
    db.commit()
    db.refresh(event)

    print(
        "✅ AI event created: "
        f"id={event.id} "
        f"type={event.event_type} "
        f"premise_id={event.premise_id} "
        f"profile_id={event.profile_id}"
    )

    try:
        broadcast_ai_event_once(event)
    except Exception as exc:
        print(f"⚠️ Failed to broadcast AI event notification: {exc}")

    return event


def create_ai_event_from_classification(
    db: Session,
    *,
    premise_id: int,
    classification: dict[str, Any],
    image_path: str,
    is_acknowledged: bool = False,
) -> AIEvent:
    return create_ai_event(
        db,
        premise_id=premise_id,
        event_type=classification["event_type"],
        profile_id=classification["profile_id"],
        confidence_score=classification["confidence_score"],
        image_path=image_path,
        is_acknowledged=is_acknowledged,
    )
