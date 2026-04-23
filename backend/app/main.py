from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from passlib.context import CryptContext
from app.api.dev.api import api_router

app = FastAPI(title="Smart Home Security API")

# --- 1. SECURITY & CORS ---
# This allows your Flutter app and Cloudflare to talk to th e API
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], # For development, we allow all. For production, use ["https://api.philous.me"]
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# --- 3. ROUTES ---
app.include_router(api_router, prefix="/api/dev")

@app.get("/")
def read_root():
    return {"message": "Server is running on philous.me", "status": "online"}