from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.db.database import get_db
from app.middleware import get_current_user
from app.models.profile import EmergencyContact, Profile
from app.schemas.emergency_contact import (
    EmergencyContactCreate,
    EmergencyContactResponse,
    EmergencyContactUpdate,
)
from app.services.user_service import is_manager, is_owner


router = APIRouter()


def _current_profile(current_user: dict, db: Session) -> Profile:
    profile = db.query(Profile).filter(Profile.id == current_user.get("user_id")).first()
    if profile is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User profile not found.",
        )
    if profile.premise_id is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Current user is not assigned to a premise.",
        )
    return profile


def _require_contact_manager(profile: Profile) -> None:
    if not (is_owner(profile) or is_manager(profile)):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only an owner or manager can manage emergency contacts.",
        )


def _contact_or_404(db: Session, premise_id: int, contact_id: int) -> EmergencyContact:
    contact = (
        db.query(EmergencyContact)
        .filter(
            EmergencyContact.id == contact_id,
            EmergencyContact.premise_id == premise_id,
        )
        .first()
    )
    if contact is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Emergency contact not found.",
        )
    return contact


def _commit_contact(db: Session, contact: EmergencyContact) -> EmergencyContact:
    try:
        db.commit()
        db.refresh(contact)
        return contact
    except IntegrityError as error:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="This phone number is already an emergency contact.",
        ) from error


@router.get("", response_model=list[EmergencyContactResponse])
def list_emergency_contacts(
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    profile = _current_profile(current_user, db)
    return (
        db.query(EmergencyContact)
        .filter(EmergencyContact.premise_id == profile.premise_id)
        .order_by(
            EmergencyContact.enabled.desc(),
            EmergencyContact.priority.asc(),
            EmergencyContact.contact_name.asc(),
        )
        .all()
    )


@router.post("", response_model=EmergencyContactResponse, status_code=status.HTTP_201_CREATED)
def create_emergency_contact(
    request: EmergencyContactCreate,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    profile = _current_profile(current_user, db)
    _require_contact_manager(profile)
    contact = EmergencyContact(
        premise_id=profile.premise_id,
        contact_name=request.contact_name,
        phone_number=request.phone_number,
        relationship_label=request.relationship,
        priority=request.priority,
        enabled=request.enabled,
    )
    db.add(contact)
    return _commit_contact(db, contact)


@router.put("/{contact_id}", response_model=EmergencyContactResponse)
def update_emergency_contact(
    contact_id: int,
    request: EmergencyContactUpdate,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    profile = _current_profile(current_user, db)
    _require_contact_manager(profile)
    contact = _contact_or_404(db, profile.premise_id, contact_id)

    changes = request.model_dump(exclude_unset=True)
    if "relationship" in changes:
        changes["relationship_label"] = changes.pop("relationship")
    for field_name, value in changes.items():
        setattr(contact, field_name, value)

    return _commit_contact(db, contact)


@router.delete("/{contact_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_emergency_contact(
    contact_id: int,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    profile = _current_profile(current_user, db)
    _require_contact_manager(profile)
    contact = _contact_or_404(db, profile.premise_id, contact_id)
    db.delete(contact)
    db.commit()
    return None
