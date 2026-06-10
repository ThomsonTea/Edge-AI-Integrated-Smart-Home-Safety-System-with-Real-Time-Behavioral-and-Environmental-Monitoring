from fastapi import APIRouter, HTTPException, status, Depends
from sqlalchemy.orm import Session

from app.schemas.user import UserCreate
from app.db import database
from app.models.profile import Profile
from app.services.user_service import UserService
from app.middleware.jwt_auth import verify_token

router = APIRouter()

@router.get("/profiles")
def get_profiles(
    db: Session = Depends(database.get_db),
    current_user: dict = Depends(verify_token)
):
    profiles = db.query(Profile).all()
    return [
        {
            "id": profile.id,
            "username": profile.username,
            "phone_number": profile.phone_number,
            "email": profile.email,
            "group_type": profile.group_type,
        }
        for profile in profiles
    ]


@router.post("/register")
def register(
    userData: UserCreate,
    db: Session = Depends(database.get_db)
):
    service = UserService(db)

    try:
        user = service.create_user(
            userData.username,
            userData.password,
            userData.email,
            userData.phone_number,
            userData.group_type,
        )

        return {
            "message": "User created successfully",
            "user": {
                "id": user.id,
                "username": user.username,
                "phone_number": user.phone_number,
                "email": user.email,
                "group_type": user.group_type,
            }
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
    profile = db.query(Profile).filter(Profile.id == user_id).first()
    if not profile:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
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