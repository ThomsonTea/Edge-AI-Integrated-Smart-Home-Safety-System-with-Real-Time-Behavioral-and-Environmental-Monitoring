from fastapi import APIRouter
from .endpoints import user
from .endpoints import camera

api_router = APIRouter()

api_router.include_router(user.router, prefix="/profile", tags=["user"])
api_router.include_router(camera.router, prefix="/camera", tags=["camera"])