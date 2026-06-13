from pathlib import Path
from typing import Optional
from uuid import uuid4

from fastapi import HTTPException, UploadFile, status
from sqlalchemy.orm import Session, joinedload

from app.models.profile import Profile
from app.services.face_service import FaceRegistrationError, FaceService
from app.services.user_service import UserService

BASE_DIR = Path(__file__).resolve().parents[2]
PROFILE_PICTURE_DIR = BASE_DIR / "storage" / "profile_pictures"
MAX_PROFILE_PICTURE_BYTES = 5 * 1024 * 1024
ALLOWED_PROFILE_PICTURE_TYPES = {
    "image/jpeg": ".jpg",
    "image/png": ".png",
    "image/webp": ".webp",
}


class ProfileService:
    def __init__(self, db: Session):
        self.db = db

    def get_current_profile(self, current_user: dict) -> Profile:
        user_id = current_user.get("user_id")
        profile = (
            self.db.query(Profile)
            .options(joinedload(Profile.premise))
            .filter(Profile.id == user_id)
            .first()
        )

        if profile is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Current user profile not found",
            )

        return profile

    def profile_response(self, profile: Profile) -> dict:
        premise = profile.premise

        return {
            "id": profile.id,
            "username": profile.username,
            "email": profile.email,
            "phone_number": profile.phone_number,
            "group_type": profile.group_type,
            "role": profile.group_type,
            "premise_id": profile.premise_id,
            "premise_name": premise.name if premise is not None else None,
            "profile_image_path": profile.profile_image_path,
            "face_registered": bool(profile.face_signature),
            "last_seen": profile.last_seen,
            "is_blacklisted": bool(profile.is_blacklisted),
        }

    def update_current_profile(
        self,
        profile: Profile,
        *,
        username: Optional[str] = None,
        email: Optional[str] = None,
        phone_number: Optional[str] = None,
    ) -> Profile:
        if username is not None:
            value = username.strip()
            if not value:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Username cannot be empty",
                )

            existing_profile = (
                self.db.query(Profile)
                .filter(Profile.username == value, Profile.id != profile.id)
                .first()
            )
            if existing_profile is not None:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Username already exists",
                )

            profile.username = value

        if email is not None:
            profile.email = email.strip()

        if phone_number is not None:
            value = phone_number.strip()
            profile.phone_number = value or None

        self.db.commit()
        self.db.refresh(profile)
        return profile

    def change_password(
        self,
        profile: Profile,
        *,
        current_password: str,
        new_password: str,
        confirm_password: str,
    ) -> None:
        user_service = UserService(self.db)

        if not user_service.verify_password(
            current_password,
            profile.hash_password or "",
        ):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Current password is incorrect",
            )

        if len(new_password) < 6:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="New password must be at least 6 characters long",
            )

        if new_password != confirm_password:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="New password and confirm password do not match",
            )

        profile.hash_password = user_service.hash_password(new_password)
        self.db.commit()

    async def update_profile_picture(
        self,
        profile: Profile,
        image: UploadFile,
    ) -> Profile:
        extension = ALLOWED_PROFILE_PICTURE_TYPES.get(image.content_type or "")

        if extension is None:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Profile picture must be a JPEG, PNG, or WebP image",
            )

        image_bytes = await image.read()

        if not image_bytes:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Profile picture file is empty",
            )

        if len(image_bytes) > MAX_PROFILE_PICTURE_BYTES:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Profile picture must be 5MB or smaller",
            )

        PROFILE_PICTURE_DIR.mkdir(parents=True, exist_ok=True)
        filename = f"profile_{profile.id}_{uuid4().hex}{extension}"
        path = PROFILE_PICTURE_DIR / filename
        path.write_bytes(image_bytes)

        profile.profile_image_path = f"/storage/profile_pictures/{filename}"
        self.db.commit()
        self.db.refresh(profile)
        return profile

    async def register_current_user_face(
        self,
        profile: Profile,
        image: UploadFile,
    ) -> Profile:
        image_bytes = await image.read()
        face_service = FaceService(self.db)

        try:
            return face_service.register_face_for_profile(
                profile_id=profile.id,
                image_bytes=image_bytes,
            )
        except FaceRegistrationError as exc:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=str(exc),
            ) from exc
