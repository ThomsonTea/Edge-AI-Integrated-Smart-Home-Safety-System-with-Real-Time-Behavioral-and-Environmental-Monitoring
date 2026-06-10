from fastapi import APIRouter, Depends, File, HTTPException, Path, UploadFile, status
from sqlalchemy.orm import Session

from app.db.database import get_db
from app.middleware.jwt_auth import verify_token
from app.models.profile import Profile
from app.schemas.face import FaceRegistrationResponse
from app.services.face_service import FaceRegistrationError, FaceService

router = APIRouter()


def _get_current_profile(current_user: dict, db: Session) -> Profile:
    user_id = current_user.get("user_id")
    profile = db.query(Profile).filter(Profile.id == user_id).first()

    if profile is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Current user profile not found",
        )

    return profile


def _ensure_admin(profile: Profile) -> None:
    role = (profile.group_type or "").strip().lower()

    if role != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin access required",
        )


def _ensure_same_premise(admin: Profile, target: Profile) -> None:
    if admin.premise_id is None or target.premise_id is None:
        return

    if admin.premise_id != target.premise_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Cannot register a face for a profile in another premise",
        )


@router.post(
    "/profiles/{profile_id}/face",
    response_model=FaceRegistrationResponse,
)
async def register_profile_face(
    profile_id: int = Path(..., ge=1),
    image: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: dict = Depends(verify_token),
):
    admin = _get_current_profile(current_user=current_user, db=db)
    _ensure_admin(admin)

    target_profile = db.query(Profile).filter(Profile.id == profile_id).first()

    if target_profile is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Profile not found",
        )

    _ensure_same_premise(admin=admin, target=target_profile)

    image_bytes = await image.read()
    service = FaceService(db)

    try:
        updated_profile = service.register_face_for_profile(
            profile_id=profile_id,
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

    return FaceRegistrationResponse(
        message="Face registered successfully",
        profile_id=updated_profile.id,
        has_face_signature=bool(updated_profile.face_signature),
    )
