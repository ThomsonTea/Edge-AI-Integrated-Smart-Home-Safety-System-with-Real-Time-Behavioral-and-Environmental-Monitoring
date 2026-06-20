from fastapi import APIRouter, HTTPException, status, Depends
from sqlalchemy.orm import Session

from app.schemas.user import UserCreate
from app.db import database
from app.models.profile import Profile
from app.services.user_service import UserService, is_owner, normalize_role
from app.middleware.jwt_auth import verify_token

router = APIRouter()


def _profile_response(profile: Profile) -> dict:
    return {
        "id": profile.id,
        "username": profile.username,
        "phone_number": profile.phone_number,
        "email": profile.email,
        "group_type": normalize_role(profile.group_type),
        "role": normalize_role(profile.group_type),
        "premise_id": profile.premise_id,
        "is_primary_owner": is_owner(profile),
    }


@router.get("/profiles")
def get_profiles(
    db: Session = Depends(database.get_db),
    current_user: dict = Depends(verify_token)
):
    service = UserService(db)
    current_profile = service.get_profile_by_token_payload(current_user)
    service.require_owner_or_manager(current_profile)

    if current_profile.premise_id is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Current user is not assigned to a premise.",
        )

    profiles = (
        db.query(Profile)
        .filter(Profile.premise_id == current_profile.premise_id)
        .order_by(Profile.id.asc())
        .all()
    )
    return [_profile_response(profile) for profile in profiles]


@router.post("/register")
def register(
    userData: UserCreate,
    db: Session = Depends(database.get_db),
    current_user: dict = Depends(verify_token),
):
    service = UserService(db)

    try:
        current_profile = service.get_profile_by_token_payload(current_user)
        role = service.validate_user_creation(
            current_profile=current_profile,
            requested_role=userData.group_type,
        )
        user = service.create_user(
            userData.username,
            userData.password,
            userData.email,
            userData.phone_number,
            role,
            premise_id=current_profile.premise_id,
        )

        return {
            "message": "User created successfully",
            "user": _profile_response(user),
        }

    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )


@router.delete("/profiles/{user_id}")
def delete_profile(
    user_id: int,
    db: Session = Depends(database.get_db),
    current_user: dict = Depends(verify_token)
):
    service = UserService(db)
    current_profile = service.get_profile_by_token_payload(current_user)
    profile = db.query(Profile).filter(Profile.id == user_id).first()
    if not profile:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )

    service.ensure_can_delete_user(
        current_profile=current_profile,
        target_profile=profile,
    )

    db.delete(profile)
    db.commit()

    return {"message": "User deleted successfully"}


@router.get("/me")
def get_current_user_data(
    current_user: dict = Depends(verify_token)
):
    return {
        "message": "Token is valid",
        "user": current_user
    }
