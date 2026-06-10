from fastapi import APIRouter, Depends
from fastapi.responses import StreamingResponse

from app.services.shared_camera import camera_service
from app.middleware.jwt_auth import verify_token

# Create the router
router = APIRouter(
    dependencies=[Depends(verify_token)]
)

@router.get("/video_feed")
def video_feed():
    """
    Endpoint for the mobile app to receive the live, AI-annotated video feed.
    URL will be: https://api.philous.me/api/dev/camera/video_feed
    """
    return StreamingResponse(
        camera_service.generate_frames(), 
        media_type="multipart/x-mixed-replace; boundary=frame"
    )