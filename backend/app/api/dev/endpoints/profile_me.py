from typing import Optional

from fastapi import APIRouter, Depends, File, UploadFile
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.db import database
from app.middleware.jwt_auth import verify_token
from app.services.profile_service import ProfileService

router = APIRouter()


class ProfileUpdateRequest(BaseModel):
    username: Optional[str] = None
    email: Optional[str] = None
    phone_number: Optional[str] = None


class PasswordChangeRequest(BaseModel):
    current_password: str
    new_password: str
    confirm_password: str


@router.get("/me")
def get_my_profile(
    current_user: dict = Depends(verify_token),
    db: Session = Depends(database.get_db),
):
    service = ProfileService(db)
    profile = service.get_current_profile(current_user)
    return service.profile_response(profile)


@router.put("/me")
def update_my_profile(
    request: ProfileUpdateRequest,
    current_user: dict = Depends(verify_token),
    db: Session = Depends(database.get_db),
):
    service = ProfileService(db)
    profile = service.get_current_profile(current_user)
    updated_profile = service.update_current_profile(
        profile,
        username=request.username,
        email=request.email,
        phone_number=request.phone_number,
    )
    return service.profile_response(updated_profile)


@router.put("/me/password")
def change_my_password(
    request: PasswordChangeRequest,
    current_user: dict = Depends(verify_token),
    db: Session = Depends(database.get_db),
):
    service = ProfileService(db)
    profile = service.get_current_profile(current_user)
    service.change_password(
        profile,
        current_password=request.current_password,
        new_password=request.new_password,
        confirm_password=request.confirm_password,
    )

    return {"message": "Password changed successfully"}


@router.post("/me/profile-picture")
async def update_my_profile_picture(
    image: UploadFile = File(...),
    current_user: dict = Depends(verify_token),
    db: Session = Depends(database.get_db),
):
    service = ProfileService(db)
    profile = service.get_current_profile(current_user)
    updated_profile = await service.update_profile_picture(profile, image)

    return {
        "message": "Profile picture updated successfully",
        "profile_image_path": updated_profile.profile_image_path,
        "profile": service.profile_response(updated_profile),
    }


@router.post("/me/face")
async def register_my_face(
    image: UploadFile = File(...),
    current_user: dict = Depends(verify_token),
    db: Session = Depends(database.get_db),
):
    service = ProfileService(db)
    profile = service.get_current_profile(current_user)
    updated_profile = await service.register_current_user_face(profile, image)

    return {
        "message": "Face registered successfully",
        "face_registered": bool(updated_profile.face_signature),
        "profile": service.profile_response(updated_profile),
    }
