from fastapi import APIRouter

from .endpoints import ai_events
from .endpoints import auth
from .endpoints import user
from .endpoints import camera

api_router = APIRouter()

api_router.include_router(auth.router, prefix="/profile", tags=["auth"])
api_router.include_router(user.router, prefix="/profile", tags=["user"])
api_router.include_router(camera.router, prefix="/camera", tags=["camera"])
api_router.include_router(ai_events.router, prefix="/ai_events", tags=["ai_events"])
