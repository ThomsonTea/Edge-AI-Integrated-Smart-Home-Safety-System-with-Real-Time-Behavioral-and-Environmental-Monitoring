from fastapi import APIRouter, HTTPException, WebSocket, WebSocketDisconnect, status
from sqlalchemy.orm import Session

from app.db.database import SessionLocal
from app.middleware.jwt_auth import decode_token
from app.models.profile import Profile
from app.services.notification_connection_manager import (
    notification_connection_manager,
)

router = APIRouter()


def _auth_close_reason(error: HTTPException) -> str:
    detail = str(error.detail).lower()

    if "expired" in detail:
        return "token_expired"

    return "auth_failed"


def _profile_from_token(token: str, db: Session) -> Profile | None:
    payload = decode_token(token)
    user_id = payload.get("user_id")

    if user_id is None:
        return None

    return db.query(Profile).filter(Profile.id == user_id).first()


@router.websocket("/ws/notifications")
async def notifications_websocket(websocket: WebSocket):
    token = websocket.query_params.get("token")

    if not token:
        await websocket.close(
            code=status.WS_1008_POLICY_VIOLATION,
            reason="auth_failed",
        )
        return

    db = SessionLocal()

    try:
        profile = _profile_from_token(token=token, db=db)

        if profile is None or profile.premise_id is None:
            await websocket.close(
                code=status.WS_1008_POLICY_VIOLATION,
                reason="auth_failed",
            )
            return

        premise_id = profile.premise_id
        await notification_connection_manager.connect(websocket, premise_id)

        while True:
            await websocket.receive_text()

    except HTTPException as error:
        await websocket.close(
            code=status.WS_1008_POLICY_VIOLATION,
            reason=_auth_close_reason(error),
        )
    except WebSocketDisconnect:
        pass
    except Exception:
        await websocket.close(code=status.WS_1011_INTERNAL_ERROR)
    finally:
        if "premise_id" in locals():
            notification_connection_manager.disconnect(websocket, premise_id)
        db.close()
