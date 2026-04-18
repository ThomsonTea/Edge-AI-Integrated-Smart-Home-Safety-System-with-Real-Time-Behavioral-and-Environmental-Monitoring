from fastapi import FastAPI, Depends, HTTPException
from sqlalchemy.orm import Session
import models, database
from passlib.context import CryptContext

app = FastAPI(title="Smart Home Security API")

# Setup Password Hashing
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# 1. Root Test Route
@app.get("/")
def read_root():
    return {"message": "Server is running...", "status": "online"}

# 2. Basic Sign-Up Route (To create your first Admin)
@app.post("/register")
def create_user(full_name: str, email: str, password: str, db: Session = Depends(database.get_db)):
    # Check if user already exists
    db_user = db.query(models.Profile).filter(models.Profile.full_name == full_name).first()
    
    if db_user:
        raise HTTPException(status_code=400, detail="User already registered")
    
    # Hash the password
    hashed_pass = pwd_context.hash(password)
    
    # Create the user object
    new_user = models.Profile(
        full_name=full_name,
        email=email,
        hash_password=hashed_pass,
        group_type="Owner"
    )
    
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    return {"message": "User created successfully", "user_id": new_user.id}