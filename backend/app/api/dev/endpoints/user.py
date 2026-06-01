from fastapi import APIRouter, HTTPException, status, Depends
from sqlalchemy.orm import Session
from app.schemas.user import UserLogin, UserCreate
from app.db import database
from app.services.user_service import UserService

router = APIRouter()

@router.post("/login")
def login(loginData: UserLogin, db: Session = Depends(database.get_db)):

    userService = UserService(db)
    user = userService.authenticate_user(loginData.username, loginData.password)
    
    if not user:
        raise HTTPException(status_code=401, detail="Invalid credentials")
    
    # Generate JWT token
    token = userService.create_access_token(user.id, user.username)
    
    return {
        "message": f"Welcome back, {user.username}!",
        "token": token,
        "user": {
            "id": user.id,
            "username": user.username
        }
    }

@router.post("/register")
def register(userData: UserCreate, db: Session = Depends(database.get_db)):
    service = UserService(db)
    try:
        return service.create_user(userData.username, userData.password)
    except ValueError as e:
        # This is where you 'handle' the bad request
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e) # Sends the message "Password too short" to the user
        )
