"""Premise data-retention settings and manual cleanup endpoints."""

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy.orm import Session

from app.db.database import get_db
from app.middleware import get_current_user
from app.models.profile import PremiseSetting, Profile
from app.services.data_retention_service import cleanup_premise_data
from app.services.user_service import is_manager, is_owner


router = APIRouter()


class RetentionSettingsResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    premise_id: int
    auto_delete_images: bool
    image_retention_days: int
    event_retention_days: int
    sensor_retention_days: int
    preserve_unacknowledged: bool
    preserve_critical: bool


class RetentionSettingsUpdate(BaseModel):
    auto_delete_images: bool
    image_retention_days: int = Field(ge=1, le=3650)
    event_retention_days: int = Field(ge=1, le=3650)
    sensor_retention_days: int = Field(ge=1, le=3650)
    preserve_unacknowledged: bool
    preserve_critical: bool


class CleanupResponse(BaseModel):
    events_deleted: int
    sensor_readings_deleted: int
    images_deleted: int
    image_references_cleared: int
    image_delete_failures: int


def _current_profile(current_user: dict, db: Session) -> Profile:
    profile = db.query(Profile).filter(Profile.id == current_user.get("user_id")).first()
    if profile is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User profile not found")
    if profile.premise_id is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Current user is not assigned to a premise",
        )
    return profile


def _require_retention_manager(profile: Profile) -> None:
    if not (is_owner(profile) or is_manager(profile)):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only owner or manager can manage data retention",
        )


def _get_or_create_settings(db: Session, premise_id: int) -> PremiseSetting:
    settings = db.query(PremiseSetting).filter(PremiseSetting.premise_id == premise_id).first()
    if settings is None:
        settings = PremiseSetting(premise_id=premise_id)
        db.add(settings)
        db.commit()
        db.refresh(settings)
    return settings


@router.get("/retention", response_model=RetentionSettingsResponse)
def get_retention_settings(
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    profile = _current_profile(current_user, db)
    return _get_or_create_settings(db, profile.premise_id)


@router.put("/retention", response_model=RetentionSettingsResponse)
def update_retention_settings(
    request: RetentionSettingsUpdate,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    profile = _current_profile(current_user, db)
    _require_retention_manager(profile)
    settings = _get_or_create_settings(db, profile.premise_id)

    for field_name, value in request.model_dump().items():
        setattr(settings, field_name, value)
    db.commit()
    db.refresh(settings)
    return settings


@router.post("/retention/cleanup", response_model=CleanupResponse)
def run_retention_cleanup(
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    profile = _current_profile(current_user, db)
    _require_retention_manager(profile)
    settings = _get_or_create_settings(db, profile.premise_id)
    return cleanup_premise_data(db, settings).to_dict()
