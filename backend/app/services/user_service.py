import os

import jwt
from datetime import datetime, timedelta

from app.models.profile import Profile
from passlib.context import CryptContext
from sqlalchemy.orm import Session

class UserService:
    # Secret key for JWT - in production, use environment variable
    SECRET_KEY = os.getenv("SECRET_KEY", "your-secret-key-change-in-production")
    ALGORITHM = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES = 30

    pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

    def __init__(self, db: Session):
        self.db = db

    def create_user(self, username: str, password: str, email: str = None, phone_number: str = None) -> Profile:
        hashed_password = self.hash_password(password)
        new_user = Profile(username=username, hash_password=hashed_password, email=email, phone_number=phone_number)

        if self.db.query(Profile).filter(Profile.username == username).first():
            raise ValueError("User with this full name already exists.")
        
        if(len(password) < 6):
            raise ValueError("Password must be at least 6 characters long.")
        
        self.db.add(new_user)
        self.db.commit()
        self.db.refresh(new_user)
        return new_user

    def hash_password(self, password: str) -> str:
        return self.pwd_context.hash(password)

    def verify_password(self, plain_password: str, hashed_password: str) -> bool:
        return self.pwd_context.verify(plain_password, hashed_password)

    def authenticate_user(self, username: str, password: str) -> Profile:
        # Search the Profile table in the DB
        user = self.db.query(Profile).filter(Profile.username == username).first()
        
        if user and self.verify_password(password, user.hash_password):
            return user
        return None
    
    def create_access_token(self, user_id: int, username: str):
        """Generate a JWT token for the user"""
        payload = {
            "user_id": user_id,
            "username": username,
            "exp": datetime.utcnow() + timedelta(minutes=self.ACCESS_TOKEN_EXPIRE_MINUTES),
            "iat": datetime.utcnow()
        }
        token = jwt.encode(payload, self.SECRET_KEY, algorithm=self.ALGORITHM)
        return token