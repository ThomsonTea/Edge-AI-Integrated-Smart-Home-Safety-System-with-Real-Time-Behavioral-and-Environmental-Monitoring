from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from passlib.context import CryptContext
from app.api.dev.api import api_router
from app.services.shared_camera import camera_service

app = FastAPI(title="Smart Home Security API")

BASE_DIR = Path(__file__).resolve().parents[1]
STORAGE_DIR = BASE_DIR / "storage"
STORAGE_DIR.mkdir(parents=True, exist_ok=True)


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

# --- 2. STATIC FILES ---
app.mount("/storage", StaticFiles(directory=str(STORAGE_DIR)), name="storage")

# --- 3. ROUTES ---
app.include_router(api_router, prefix="/api/dev")

@app.on_event("startup")
def start_camera_services():
    camera_service.start_camera_loop()
    camera_service.start_ai_detection_loop()

@app.get("/")
def read_root():
    return {"message": "Server is running on philous.me", "status": "online"}
