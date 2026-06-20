from typing import Optional
from pydantic import BaseModel

class UserLogin(BaseModel):
    username: str
    password: str

class UserCreate(BaseModel):
    username: str
    password: str
    email: str
    phone_number: str
    group_type: Optional[str] = None

class UserUpdate(BaseModel):
    username: Optional[str] = None
    email: Optional[str] = None
    phone_number: Optional[str] = None
    group_type: Optional[str] = None

class UserPasswordReset(BaseModel):
    new_password: str
    confirm_password: str

class AIEventCreate(BaseModel):
    event_type: str
    confidence_score: float
    image_path: str
