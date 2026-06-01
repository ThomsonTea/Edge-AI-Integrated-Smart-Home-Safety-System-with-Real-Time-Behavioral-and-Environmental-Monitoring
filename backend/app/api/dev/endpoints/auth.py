from fastapi import APIRouter, Depends, HTTPException, status
from fastapi import HTTPException, status
from requests import Session

from backend.app.db import database
from backend.app.schemas.user import UserLogin
from backend.app.services.user_service import UserService


router = APIRouter()

@router.post("/login")
def login(
    loginData: UserLogin,
    db: Session = Depends(database.get_db)
):
    service = UserService(db)

    user = service.authenticate_user(
        loginData.username,
        loginData.password
    )

    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid credentials"
        )

    token = service.create_access_token(
        user.id,
        user.username,
        user.group_type
    )

    return {
        "token": token,
        "user": {
            "id": user.id,
            "username": user.username,
            "role": user.group_type
        }
    }