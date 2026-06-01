from fastapi import APIRouter, HTTPException, status, Depends
from sqlalchemy.orm import Session

from app.schemas.user import UserLogin, UserCreate
from app.db import database
from app.services.user_service import UserService
from app.middleware.jwt_auth import verify_token

router = APIRouter(
    dependencies=[Depends(verify_token)]
)

@router.get("/profiles")
def get_profiles(current_user=Depends(verify_token)):
    return {"user": current_user}


@router.post("/register")
def register(
    userData: UserCreate,
    db: Session = Depends(database.get_db)
):
    service = UserService(db)

    try:
        user = service.create_user(
            userData.username,
            userData.password
        )

        return {
            "message": "User created successfully",
            "user": {
                "id": user.id,
                "username": user.username
            }
        }

    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )
    

@router.get("/me")
def get_current_user_data(
    current_user: dict = Depends(verify_token)
):
    return {
        "message": "Token is valid",
        "user": current_user
    }