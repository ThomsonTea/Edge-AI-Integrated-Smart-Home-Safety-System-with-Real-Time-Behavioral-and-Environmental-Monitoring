from fastapi import FastAPI, Depends, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
from pydantic import BaseModel
import models, database
from passlib.context import CryptContext

app = FastAPI(title="Smart Home Security API")

# --- 1. SECURITY & CORS ---
# This allows your Flutter app and Cloudflare to talk to the API
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], # For development, we allow all. For production, use ["https://api.philous.me"]
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# --- 2. DATA SCHEMAS (Pydantic) ---
class UserCreate(BaseModel):
    full_name: str
    email: str
    password: str

class AIEventCreate(BaseModel):
    event_type: str
    confidence_score: float
    image_path: str

# --- 3. ROUTES ---

@app.get("/")
def read_root():
    return {"message": "Server is running on philous.me", "status": "online"}

@app.post("/register")
def create_user(user: UserCreate, db: Session = Depends(database.get_db)):
    # Use user.email instead of just email
    db_user = db.query(models.Profile).filter(models.Profile.email == user.email).first()
    
    if db_user:
        raise HTTPException(status_code=400, detail="Email already registered")
    
    hashed_pass = pwd_context.hash(user.password)
    
    new_user = models.Profile(
        full_name=user.full_name,
        email=user.email,
        hash_password=hashed_pass,
        group_type="Owner"
    )
    
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    return {"message": "User created successfully", "user_id": new_user.id}

@app.post("/ai_event")
def create_ai_event(event: AIEventCreate, db: Session = Depends(database.get_db)):
    new_event = models.AIEvent(
        event_type=event.event_type,
        confidence_score=event.confidence_score,
        image_path=event.image_path
    )
    db.add(new_event)
    db.commit()
    return {"status": "Event logged to database"}