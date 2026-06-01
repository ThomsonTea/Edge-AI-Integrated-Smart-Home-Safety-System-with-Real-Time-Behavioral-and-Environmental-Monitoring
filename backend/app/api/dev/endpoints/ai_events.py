"""Protected AI Events Endpoint - Requires JWT Authentication"""

from fastapi import APIRouter, Depends, status, HTTPException
from sqlalchemy.orm import Session
from app.db.database import get_db
from app.middleware import get_current_user
from app.models.event import AIEvent
from pydantic import BaseModel
from typing import List
from datetime import datetime

router = APIRouter()


class AIEventResponse(BaseModel):
    """Schema for AI Event response"""
    id: int
    event_type: str
    confidence_score: float
    image_path: str
    is_acknowledged: bool
    timestamp: datetime
    premise_id: int
    
    class Config:
        from_attributes = True


@router.get("/", response_model=List[AIEventResponse])
def get_ai_events(
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
    limit: int = 50,
):
    """
    Get AI detection events for the current user's premise.
    
    🔒 **JWT Required**: Must include Bearer token in Authorization header
    
    Example:
        GET /api/dev/ai_events
        Authorization: Bearer YOUR_JWT_TOKEN
    
    Returns:
        List of AI events ordered by most recent first
        
    Raises:
        401: If token is missing, invalid, or expired
        404: If user's premise not found
    """
    user_id = current_user.get("user_id")
    
    # Get user's profile to find their premise
    from app.models.profile import Profile
    user = db.query(Profile).filter(Profile.id == user_id).first()
    
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User profile not found"
        )
    
    if not user.premise_id:
        return []  # User has no premise assigned
    
    # Get events for user's premise, ordered by most recent first
    events = db.query(AIEvent)\
        .filter(AIEvent.premise_id == user.premise_id)\
        .order_by(AIEvent.timestamp.desc())\
        .limit(limit)\
        .all()
    
    return events


@router.get("/{event_id}", response_model=AIEventResponse)
def get_ai_event(
    event_id: int,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Get a specific AI event by ID.
    
    🔒 **JWT Required**
    
    Only allows access to events in user's premise.
    
    Args:
        event_id: ID of the event to retrieve
        
    Returns:
        AI event details
        
    Raises:
        401: If token is invalid
        403: If event belongs to different user's premise
        404: If event not found
    """
    user_id = current_user.get("user_id")
    
    # Get user's profile
    from app.models.profile import Profile
    user = db.query(Profile).filter(Profile.id == user_id).first()
    
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )
    
    # Get event
    event = db.query(AIEvent).filter(AIEvent.id == event_id).first()
    
    if not event:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Event not found"
        )
    
    # Verify event belongs to user's premise
    if event.premise_id != user.premise_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized to access this event"
        )
    
    return event


@router.put("/{event_id}/acknowledge")
def acknowledge_event(
    event_id: int,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Mark an AI event as acknowledged by the user.
    
    🔒 **JWT Required**
    
    Args:
        event_id: ID of the event to acknowledge
        
    Returns:
        Updated event
        
    Raises:
        401: If token is invalid
        403: If event belongs to different user's premise
        404: If event not found
    """
    user_id = current_user.get("user_id")
    
    # Get user's profile
    from app.models.profile import Profile
    user = db.query(Profile).filter(Profile.id == user_id).first()
    
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )
    
    # Get event
    event = db.query(AIEvent).filter(AIEvent.id == event_id).first()
    
    if not event:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Event not found"
        )
    
    # Verify authorization
    if event.premise_id != user.premise_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized to acknowledge this event"
        )
    
    # Update event
    event.is_acknowledged = True
    db.commit()
    db.refresh(event)
    
    return {
        "message": "Event acknowledged",
        "event": event
    }
