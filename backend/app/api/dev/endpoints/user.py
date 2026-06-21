from fastapi import APIRouter, File, HTTPException, Path, UploadFile, status, Depends
from sqlalchemy.orm import Session

from app.schemas.user import UserCreate, UserPasswordReset, UserUpdate
from app.db import database
from app.models.profile import Profile
from app.services.face_service import FaceRegistrationError, FaceService
from app.services.image_upload_validation import read_validated_image_upload
from app.services.user_service import UserService, is_owner, normalize_role
from app.middleware.jwt_auth import verify_token

router = APIRouter()
users_router = APIRouter()


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
        "face_registered": bool(profile.face_signature),
    }


def _current_profile(service: UserService, current_user: dict) -> Profile:
    return service.get_profile_by_token_payload(current_user)


def _managed_target_or_404(db: Session, user_id: int) -> Profile:
    profile = db.query(Profile).filter(Profile.id == user_id).first()
    if not profile:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )

    return profile


def _managed_profiles_for_current_user(
    db: Session,
    current_profile: Profile,
) -> list[Profile]:
    if current_profile.premise_id is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Current user is not assigned to a premise.",
        )

    return (
        db.query(Profile)
        .filter(Profile.premise_id == current_profile.premise_id)
        .order_by(Profile.id.asc())
        .all()
    )


@users_router.get("")
def list_users(
    db: Session = Depends(database.get_db),
    current_user: dict = Depends(verify_token),
):
    service = UserService(db)
    current_profile = _current_profile(service, current_user)

    if not (normalize_role(current_profile.group_type) in {"owner", "manager"}):
        return [_profile_response(current_profile)]

    profiles = _managed_profiles_for_current_user(db, current_profile)
    return [_profile_response(profile) for profile in profiles]


@users_router.post("")
def create_managed_user(
    userData: UserCreate,
    db: Session = Depends(database.get_db),
    current_user: dict = Depends(verify_token),
):
    service = UserService(db)

    try:
        current_profile = _current_profile(service, current_user)
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


@users_router.put("/{user_id}")
def update_managed_user(
    user_id: int,
    request: UserUpdate,
    db: Session = Depends(database.get_db),
    current_user: dict = Depends(verify_token),
):
    service = UserService(db)
    current_profile = _current_profile(service, current_user)
    target_profile = _managed_target_or_404(db, user_id)

    updated = service.update_managed_user(
        current_profile=current_profile,
        target_profile=target_profile,
        username=request.username,
        email=request.email,
        phone_number=request.phone_number,
        group_type=request.group_type,
    )

    return {
        "message": "User updated successfully",
        "user": _profile_response(updated),
    }


@users_router.delete("/{user_id}")
def delete_managed_user(
    user_id: int,
    db: Session = Depends(database.get_db),
    current_user: dict = Depends(verify_token)
):
    service = UserService(db)
    current_profile = _current_profile(service, current_user)
    profile = _managed_target_or_404(db, user_id)
    service.ensure_can_delete_user(
        current_profile=current_profile,
        target_profile=profile,
    )

    db.delete(profile)
    db.commit()

    return {"message": "User deleted successfully"}


@users_router.put("/{user_id}/reset-password")
def reset_user_password(
    user_id: int,
    request: UserPasswordReset,
    db: Session = Depends(database.get_db),
    current_user: dict = Depends(verify_token),
):
    service = UserService(db)
    current_profile = _current_profile(service, current_user)
    target_profile = _managed_target_or_404(db, user_id)

    service.reset_managed_user_password(
        current_profile=current_profile,
        target_profile=target_profile,
        new_password=request.new_password,
        confirm_password=request.confirm_password,
    )

    return {"message": "Password reset successfully"}


@users_router.post("/{user_id}/face")
async def register_managed_user_face(
    user_id: int = Path(..., ge=1),
    image: UploadFile = File(...),
    db: Session = Depends(database.get_db),
    current_user: dict = Depends(verify_token),
):
    service = UserService(db)
    current_profile = _current_profile(service, current_user)
    target_profile = _managed_target_or_404(db, user_id)

    if not service.is_self_target(current_profile, target_profile):
        service.ensure_can_manage_user(
            current_profile=current_profile,
            target_profile=target_profile,
            owner_message="Owner face cannot be registered from User Management.",
        )

    image_bytes, _ = await read_validated_image_upload(image)

    try:
        updated_profile = FaceService(db).register_face_for_profile(
            profile_id=user_id,
            image_bytes=image_bytes,
        )
    except FaceRegistrationError as exc:
        message = str(exc)

        if message == "Profile not found.":
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=message,
            ) from exc

        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=message,
        ) from exc

    return {
        "message": "Face registered successfully",
        "profile_id": updated_profile.id,
        "has_face_signature": bool(updated_profile.face_signature),
    }


@router.get("/profiles")
def get_profiles(
    db: Session = Depends(database.get_db),
    current_user: dict = Depends(verify_token)
):
    return list_users(db=db, current_user=current_user)


@router.post("/register")
def register(
    userData: UserCreate,
    db: Session = Depends(database.get_db),
    current_user: dict = Depends(verify_token),
):
    return create_managed_user(
        userData=userData,
        db=db,
        current_user=current_user,
    )


@router.delete("/profiles/{user_id}")
def delete_profile(
    user_id: int,
    db: Session = Depends(database.get_db),
    current_user: dict = Depends(verify_token)
):
    return delete_managed_user(
        user_id=user_id,
        db=db,
        current_user=current_user,
    )


@router.get("/me")
def get_current_user_data(
    current_user: dict = Depends(verify_token)
):
    return {
        "message": "Token is valid",
        "user": current_user
    }
