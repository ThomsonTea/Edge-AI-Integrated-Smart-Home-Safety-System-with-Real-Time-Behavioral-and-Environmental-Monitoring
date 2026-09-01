from urllib.parse import quote, urlsplit, urlunsplit

import cv2
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.responses import StreamingResponse
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.db.database import get_db
from app.middleware.jwt_auth import verify_token
from app.models.device import Camera, Device
from app.schemas.camera import (
    CameraConnectionTest,
    CameraCreate,
    CameraStreamResolve,
    CameraUpdate,
)
from app.services.camera_credentials import encrypt_password
from app.services.camera_discovery import (
    ONVIFConnectionError,
    discover_onvif_cameras,
    resolve_onvif_stream,
)
from app.services.shared_camera import camera_service
from app.services.user_service import UserService

router = APIRouter(dependencies=[Depends(verify_token)])


def _current_profile(db: Session, token: dict):
    return UserService(db).get_profile_by_token_payload(token)


def _require_premise(profile) -> int:
    if profile.premise_id is None:
        raise HTTPException(status_code=400, detail="Current user is not assigned to a premise.")
    return profile.premise_id


def _require_manager(db: Session, token: dict):
    profile = _current_profile(db, token)
    UserService(db).require_owner_or_manager(profile)
    _require_premise(profile)
    return profile


def _camera_or_404(db: Session, camera_id: int, premise_id: int) -> Camera:
    camera = (db.query(Camera).join(Device).filter(
        Camera.device_id == camera_id, Device.premise_id == premise_id
    ).first())
    if camera is None:
        raise HTTPException(status_code=404, detail="Camera not found")
    return camera


def _response(camera: Camera) -> dict:
    runtime = camera_service.get_runtime_status(camera.device_id)
    return {
        "id": camera.device_id, "name": camera.device.device_name,
        "location": camera.device.location, "enabled": camera.device.enabled,
        "connection_status": "online" if runtime["camera_online"] else camera.device.connection_status,
        "stream_url": _redacted_url(camera.stream_url), "username": camera.username,
        "has_password": bool(camera.encrypted_password), "stream_protocol": camera.stream_protocol,
        "confidence_threshold": float(camera.confidence_threshold),
        "snapshot_enabled": camera.snapshot_enabled, "detection_enabled": camera.detection_enabled,
        "last_heartbeat": camera.device.last_heartbeat,
    }


def _connection_url(stream_url: str, username: str | None, password: str | None) -> str:
    parsed = urlsplit(stream_url.strip())
    if parsed.scheme not in {"rtsp", "http", "https"} or not parsed.hostname:
        raise HTTPException(status_code=422, detail="A valid RTSP, HTTP, or HTTPS stream URL is required.")
    if parsed.username or parsed.password:
        raise HTTPException(status_code=422, detail="Enter camera credentials in the username and password fields.")
    if not username:
        return stream_url.strip()
    credentials = quote(username, safe="")
    if password:
        credentials += ":" + quote(password, safe="")
    host = parsed.hostname + (f":{parsed.port}" if parsed.port else "")
    return urlunsplit((parsed.scheme, f"{credentials}@{host}", parsed.path, parsed.query, parsed.fragment))


def _redacted_url(stream_url: str) -> str:
    parsed = urlsplit(stream_url)
    host = parsed.hostname or ""
    if parsed.port:
        host += f":{parsed.port}"
    return urlunsplit((parsed.scheme, host, parsed.path, parsed.query, parsed.fragment))


@router.get("")
def list_cameras(db: Session = Depends(get_db), token: dict = Depends(verify_token)):
    premise_id = _require_premise(_current_profile(db, token))
    cameras = (db.query(Camera).join(Device).filter(Device.premise_id == premise_id)
               .order_by(Camera.device_id.asc()).all())
    return [_response(camera) for camera in cameras]


@router.post("", status_code=status.HTTP_201_CREATED)
def create_camera(request: CameraCreate, db: Session = Depends(get_db), token: dict = Depends(verify_token)):
    profile = _require_manager(db, token)
    _connection_url(request.stream_url, request.username, request.password)
    device = Device(premise_id=profile.premise_id, device_name=request.name,
                    device_type="camera", location=request.location, enabled=True,
                    connection_status="connecting")
    camera = Camera(device=device, stream_url=request.stream_url, username=request.username,
                    encrypted_password=encrypt_password(request.password),
                    stream_protocol=request.stream_protocol,
                    confidence_threshold=request.confidence_threshold,
                    snapshot_enabled=request.snapshot_enabled,
                    detection_enabled=request.detection_enabled)
    try:
        db.add(camera); db.commit(); db.refresh(camera)
    except IntegrityError:
        db.rollback()
        raise HTTPException(status_code=409, detail="A device with this name already exists at the premise.")
    camera_service.start_camera_async(camera.device_id)
    return _response(camera)


@router.patch("/{camera_id}")
def update_camera(camera_id: int, request: CameraUpdate, db: Session = Depends(get_db), token: dict = Depends(verify_token)):
    profile = _require_manager(db, token)
    camera = _camera_or_404(db, camera_id, profile.premise_id)
    values = request.model_dump(exclude_unset=True)
    if "name" in values: camera.device.device_name = values.pop("name").strip()
    if "location" in values: camera.device.location = values.pop("location")
    if "enabled" in values: camera.device.enabled = values.pop("enabled")
    if "password" in values: camera.encrypted_password = encrypt_password(values.pop("password"))
    for field, value in values.items(): setattr(camera, field, value)
    _connection_url(camera.stream_url, camera.username, None)
    try:
        db.commit(); db.refresh(camera)
    except IntegrityError:
        db.rollback()
        raise HTTPException(status_code=409, detail="A device with this name already exists at the premise.")
    camera_service.restart_camera_async(camera_id, enabled=camera.device.enabled)
    return _response(camera)


@router.delete("/{camera_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_camera(camera_id: int, db: Session = Depends(get_db), token: dict = Depends(verify_token)):
    profile = _require_manager(db, token)
    camera = _camera_or_404(db, camera_id, profile.premise_id)
    camera_service.stop_camera(camera_id)
    db.delete(camera.device); db.commit()


@router.post("/test-connection")
def test_connection(request: CameraConnectionTest, db: Session = Depends(get_db), token: dict = Depends(verify_token)):
    _require_manager(db, token)
    url = _connection_url(request.stream_url, request.username, request.password)
    try:
        capture = cv2.VideoCapture(
            url,
            cv2.CAP_FFMPEG,
            [cv2.CAP_PROP_OPEN_TIMEOUT_MSEC, 5000, cv2.CAP_PROP_READ_TIMEOUT_MSEC, 5000],
        )
    except cv2.error as exc:
        raise HTTPException(status_code=422, detail="Could not open the camera stream.") from exc
    try:
        connected = capture.isOpened()
        if connected: connected, _ = capture.read()
    finally:
        capture.release()
    if not connected:
        raise HTTPException(status_code=422, detail="Could not connect to the camera stream.")
    return {"connected": True, "message": "Camera connection successful."}


@router.get("/discover")
def discover_cameras(db: Session = Depends(get_db), token: dict = Depends(verify_token)):
    _require_manager(db, token)
    try:
        cameras = discover_onvif_cameras()
    except OSError as exc:
        raise HTTPException(
            status_code=503,
            detail="Camera discovery is unavailable on this network.",
        ) from exc
    return {"cameras": cameras, "count": len(cameras)}


@router.post("/resolve-stream")
def resolve_camera_stream(
    request: CameraStreamResolve,
    db: Session = Depends(get_db),
    token: dict = Depends(verify_token),
):
    _require_manager(db, token)
    try:
        stream_url = resolve_onvif_stream(
            request.service_url,
            request.username,
            request.password,
        )
        parsed = urlsplit(stream_url)
        clean_url = _redacted_url(stream_url)
        _connection_url(clean_url, request.username, request.password)
    except ONVIFConnectionError as exc:
        raise HTTPException(
            status_code=422,
            detail=(
                "Automatic setup could not reach this camera. Confirm its IP "
                "and enable third-party camera access (sometimes called ONVIF) "
                "in the manufacturer's app, "
                "or use Advanced setup with a direct stream URL."
            ),
        ) from exc
    except Exception as exc:
        raise HTTPException(
            status_code=422,
            detail="Could not retrieve a stream from this camera. Check its credentials and ONVIF settings.",
        ) from exc
    return {"stream_url": clean_url, "stream_protocol": parsed.scheme.lower()}


@router.get("/{camera_id}/video_feed")
def camera_video_feed(camera_id: int, db: Session = Depends(get_db), token: dict = Depends(verify_token)):
    camera = _camera_or_404(db, camera_id, _require_premise(_current_profile(db, token)))
    if not camera.device.enabled:
        raise HTTPException(status_code=409, detail="Camera is disabled")
    camera_service.start_camera(camera_id)
    return StreamingResponse(camera_service.generate_frames(camera_id), media_type="multipart/x-mixed-replace; boundary=frame")


@router.get("/video_feed")
def video_feed():
    return StreamingResponse(camera_service.generate_frames(), media_type="multipart/x-mixed-replace; boundary=frame")
