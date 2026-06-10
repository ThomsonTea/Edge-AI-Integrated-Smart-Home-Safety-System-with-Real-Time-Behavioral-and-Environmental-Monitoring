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

class AIEventCreate(BaseModel):
    event_type: str
    confidence_score: float
    image_path: str