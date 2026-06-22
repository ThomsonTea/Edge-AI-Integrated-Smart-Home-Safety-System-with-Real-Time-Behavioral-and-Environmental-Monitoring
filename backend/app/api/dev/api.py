from fastapi import APIRouter

from .endpoints import ai_events
from .endpoints import analytics
from .endpoints import auth
from .endpoints import user
from .endpoints import camera
from .endpoints import dashboard
from .endpoints import face_registration
from .endpoints import notifications_ws
from .endpoints import profile_me
from .endpoints import session
from .endpoints import sensors

api_router = APIRouter()

api_router.include_router(auth.router, prefix="/profile", tags=["auth"])
api_router.include_router(profile_me.router, prefix="/profile", tags=["profile"])
api_router.include_router(user.router, prefix="/profile", tags=["user"])
api_router.include_router(user.users_router, prefix="/users", tags=["users"])
api_router.include_router(
    face_registration.router,
    prefix="/profile",
    tags=["face_registration"],
)
api_router.include_router(camera.router, prefix="/camera", tags=["camera"])
api_router.include_router(ai_events.router, prefix="/ai_events", tags=["ai_events"])
api_router.include_router(analytics.router, prefix="/analytics", tags=["analytics"])
api_router.include_router(dashboard.router, prefix="/dashboard", tags=["dashboard"])
api_router.include_router(sensors.router, prefix="/sensors", tags=["sensors"])
api_router.include_router(notifications_ws.router, tags=["notifications"])
api_router.include_router(session.router, tags=["session"])
