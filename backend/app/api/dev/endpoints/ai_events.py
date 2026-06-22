"""Protected AI event history endpoints."""

from datetime import datetime
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Path, Query, status
from pydantic import BaseModel
from sqlalchemy.orm import Session, joinedload

from app.db.database import get_db
from app.middleware import get_current_user
from app.models.event import AIEvent
from app.models.profile import Profile
from app.services.ai_event_service import create_ai_event
from app.services.notification_service import notification_payload_for_event
from app.services.user_service import is_manager, is_owner

router = APIRouter()

TEST_EVENT_TYPES = {"known_person", "unknown_person"}


class AIEventResponse(BaseModel):
    id: int
    type: str
    event_type: str
    confidence_score: Optional[float] = None
    image_path: Optional[str] = None
    is_acknowledged: bool
    timestamp: Optional[datetime] = None
    premise_id: Optional[int] = None
    premise_name: Optional[str] = None
    profile_id: Optional[int] = None
    profile_name: Optional[str] = None


class AIEventTestCreateRequest(BaseModel):
    event_type: str
    premise_id: int
    profile_id: Optional[int] = None
    confidence_score: Optional[float] = None
    image_path: Optional[str] = None


class AcknowledgeVisibleRequest(BaseModel):
    event_ids: List[int]


class BulkDeleteEventsRequest(BaseModel):
    event_ids: List[int]


class BulkDeleteEventsResponse(BaseModel):
    message: str
    deleted_count: int


def _get_current_profile(
    current_user: dict,
    db: Session,
) -> Profile:
    user_id = current_user.get("user_id")
    user = db.query(Profile).filter(Profile.id == user_id).first()

    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User profile not found",
        )

    return user


def _event_to_response(event: AIEvent) -> dict:
    event_type = event.event_type or "Unknown Alert"
    premise_name = event.premise.name if event.premise is not None else None
    profile_name = event.profile.username if event.profile is not None else None

    return {
        "id": event.id,
        "type": event_type,
        "event_type": event_type,
        "confidence_score": (
            float(event.confidence_score)
            if event.confidence_score is not None
            else None
        ),
        "image_path": event.image_path,
        "is_acknowledged": bool(event.is_acknowledged),
        "timestamp": event.timestamp,
        "premise_id": event.premise_id,
        "premise_name": premise_name,
        "profile_id": event.profile_id,
        "profile_name": profile_name,
    }


def _ensure_event_access(user: Profile, event: AIEvent, action: str) -> None:
    if user.premise_id is None or event.premise_id != user.premise_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Not authorized to {action} this event",
        )


def _ensure_event_delete_permission(user: Profile) -> None:
    if not (is_owner(user) or is_manager(user)):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only owner or manager can delete events",
        )


def _ensure_admin_if_role_exists(current_user: dict) -> None:
    role = current_user.get("role")

    if role is None:
        return

    if str(role).strip().lower() != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin role required to create test AI events",
        )


@router.get("", response_model=List[AIEventResponse])
@router.get("/", response_model=List[AIEventResponse], include_in_schema=False)
def get_ai_events(
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
    limit: int = Query(default=50, ge=1, le=200),
    event_type: Optional[str] = Query(default=None),
    start_date: Optional[datetime] = Query(default=None),
    end_date: Optional[datetime] = Query(default=None),
    is_acknowledged: Optional[bool] = Query(default=None),
):
    user = _get_current_profile(
        current_user=current_user,
        db=db,
    )

    if not user.premise_id:
        return []

    if start_date is not None and end_date is not None and start_date > end_date:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="start_date must be before or equal to end_date",
        )

    query = (
        db.query(AIEvent)
        .options(joinedload(AIEvent.premise), joinedload(AIEvent.profile))
        .filter(AIEvent.premise_id == user.premise_id)
    )

    if event_type is not None and event_type.strip():
        query = query.filter(AIEvent.event_type == event_type.strip())

    if start_date is not None:
        query = query.filter(AIEvent.timestamp >= start_date)

    if end_date is not None:
        query = query.filter(AIEvent.timestamp <= end_date)

    if is_acknowledged is not None:
        query = query.filter(AIEvent.is_acknowledged == is_acknowledged)

    events = query.order_by(AIEvent.timestamp.desc()).limit(limit).all()

    return [_event_to_response(event) for event in events]


@router.get("/recent")
def get_recent_ai_event_notifications(
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
    limit: int = Query(default=20, ge=1, le=100),
):
    user = _get_current_profile(
        current_user=current_user,
        db=db,
    )

    if not user.premise_id:
        return []

    events = (
        db.query(AIEvent)
        .filter(AIEvent.premise_id == user.premise_id)
        .order_by(AIEvent.timestamp.desc())
        .limit(limit)
        .all()
    )

    return [notification_payload_for_event(event) for event in events]


@router.post("/test", response_model=AIEventResponse)
def create_test_ai_event(
    request: AIEventTestCreateRequest,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    _ensure_admin_if_role_exists(current_user)

    user = _get_current_profile(
        current_user=current_user,
        db=db,
    )

    if user.premise_id is None or request.premise_id != user.premise_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized to create test event for this premise",
        )

    event_type = request.event_type.strip()
    if event_type not in TEST_EVENT_TYPES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Unsupported test event type",
        )

    if request.profile_id is not None:
        profile = db.query(Profile).filter(Profile.id == request.profile_id).first()
        if profile is None or profile.premise_id != request.premise_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="profile_id must belong to the selected premise",
            )

    event = create_ai_event(
        db,
        premise_id=request.premise_id,
        event_type=event_type,
        profile_id=request.profile_id,
        confidence_score=request.confidence_score,
        image_path=request.image_path,
        is_acknowledged=False,
    )

    event_with_relationships = (
        db.query(AIEvent)
        .options(joinedload(AIEvent.premise), joinedload(AIEvent.profile))
        .filter(AIEvent.id == event.id)
        .first()
    )

    return _event_to_response(event_with_relationships or event)


@router.put("/acknowledge-visible", response_model=List[AIEventResponse])
def acknowledge_visible_events(
    request: AcknowledgeVisibleRequest,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    user = _get_current_profile(
        current_user=current_user,
        db=db,
    )

    if not user.premise_id:
        return []

    event_ids = sorted({event_id for event_id in request.event_ids if event_id > 0})
    if not event_ids:
        return []

    events = (
        db.query(AIEvent)
        .options(joinedload(AIEvent.premise), joinedload(AIEvent.profile))
        .filter(AIEvent.id.in_(event_ids))
        .filter(AIEvent.premise_id == user.premise_id)
        .all()
    )

    found_ids = {event.id for event in events}
    inaccessible_ids = set(event_ids) - found_ids
    if inaccessible_ids:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized to acknowledge one or more visible events",
        )

    for event in events:
        event.is_acknowledged = True

    db.commit()

    for event in events:
        db.refresh(event)

    return [_event_to_response(event) for event in events]


@router.delete("/bulk", response_model=BulkDeleteEventsResponse)
def bulk_delete_ai_events(
    request: BulkDeleteEventsRequest,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    user = _get_current_profile(
        current_user=current_user,
        db=db,
    )
    _ensure_event_delete_permission(user)

    event_ids = sorted({event_id for event_id in request.event_ids if event_id > 0})
    if not event_ids:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="event_ids must contain at least one event id",
        )

    events = db.query(AIEvent).filter(AIEvent.id.in_(event_ids)).all()
    found_ids = {event.id for event in events}
    missing_ids = set(event_ids) - found_ids
    if missing_ids:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="One or more events were not found",
        )

    for event in events:
        _ensure_event_access(user=user, event=event, action="delete")

    for event in events:
        db.delete(event)

    db.commit()

    return {
        "message": "Events deleted successfully",
        "deleted_count": len(events),
    }


@router.get("/{event_id}", response_model=AIEventResponse)
def get_ai_event(
    event_id: int = Path(..., ge=1),
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    user = _get_current_profile(
        current_user=current_user,
        db=db,
    )

    event = (
        db.query(AIEvent)
        .options(joinedload(AIEvent.premise), joinedload(AIEvent.profile))
        .filter(AIEvent.id == event_id)
        .first()
    )

    if not event:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Event not found",
        )

    _ensure_event_access(user=user, event=event, action="access")

    return _event_to_response(event)


@router.put("/{event_id}/acknowledge", response_model=AIEventResponse)
def acknowledge_event(
    event_id: int = Path(..., ge=1),
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    user = _get_current_profile(
        current_user=current_user,
        db=db,
    )

    event = (
        db.query(AIEvent)
        .options(joinedload(AIEvent.premise), joinedload(AIEvent.profile))
        .filter(AIEvent.id == event_id)
        .first()
    )

    if not event:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Event not found",
        )

    _ensure_event_access(user=user, event=event, action="acknowledge")

    event.is_acknowledged = True
    db.commit()
    db.refresh(event)

    return _event_to_response(event)


@router.delete("/{event_id}")
def delete_ai_event(
    event_id: int = Path(..., ge=1),
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    user = _get_current_profile(
        current_user=current_user,
        db=db,
    )
    _ensure_event_delete_permission(user)

    event = db.query(AIEvent).filter(AIEvent.id == event_id).first()

    if not event:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Event not found",
        )

    _ensure_event_access(user=user, event=event, action="delete")

    db.delete(event)
    db.commit()

    return {"message": "Event deleted successfully"}
