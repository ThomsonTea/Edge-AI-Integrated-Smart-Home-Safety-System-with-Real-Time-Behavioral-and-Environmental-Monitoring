from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status
from sqlalchemy.orm import Session

from app.db import database
from app.middleware.jwt_auth import verify_token
from app.services.face_service import FaceLoginError, FaceRegistrationError, FaceService
from app.services.user_service import UserService

router = APIRouter()


def _login_response(user, token: str) -> dict:
    return {
        "token": token,
        "user": {
            "id": user.id,
            "username": user.username,
            "role": user.group_type,
        },
    }


@router.get("/me")
def me(current_user: dict = Depends(verify_token)):
    return {
        "message": "Token is valid",
        "user": current_user,
    }


@router.post("/auth/face-login")
async def face_login(
    image: UploadFile = File(...),
    db: Session = Depends(database.get_db),
):
    image_bytes = await image.read()
    service = FaceService(db)

    try:
        decoded_image = service.decode_image(image_bytes)
        profile = service.recognize_face_for_login(
            image=decoded_image,
            db=db,
        )
    except FaceLoginError as exc:
        message = str(exc)
        status_code = (
            status.HTTP_403_FORBIDDEN
            if message == "Face login is not allowed for this profile."
            else status.HTTP_401_UNAUTHORIZED
        )

        if message in {
            "No face detected in image.",
            "Multiple faces detected in image.",
            "Face embedding could not be generated.",
        } or message.startswith("Unexpected embedding dimension"):
            status_code = status.HTTP_400_BAD_REQUEST

        raise HTTPException(status_code=status_code, detail=message) from exc
    except FaceRegistrationError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(exc),
        ) from exc

    user_service = UserService(db)
    token = user_service.create_access_token(
        profile.id,
        profile.username,
        profile.group_type,
    )

    return _login_response(profile, token)
