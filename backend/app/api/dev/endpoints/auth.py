from fastapi import APIRouter, Depends, HTTPException, status
from fastapi import HTTPException, status
from sqlalchemy.orm import Session


from app.db import database
from app.schemas.user import UserLogin
from app.services.user_service import UserService, normalize_role


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
            "role": normalize_role(user.group_type),
        }
    }
