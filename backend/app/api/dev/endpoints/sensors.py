"""Protected sensor endpoints."""

from fastapi import APIRouter, Depends

from app.middleware.jwt_auth import verify_token
from app.services.sensor_service import sensor_service

router = APIRouter(dependencies=[Depends(verify_token)])


@router.get("/latest")
def get_latest_sensor_data():
    return sensor_service.get_latest()
