import threading

from app.db.database import SessionLocal
from app.models.device import Camera, Device
from app.services.camera_service import CameraService


class CameraManager:
    """Owns one capture/detection worker per enabled database camera."""

    def __init__(self):
        self._workers: dict[int, CameraService] = {}
        self._lock = threading.Lock()

    def start_camera_loop(self):
        self.reload()

    def start_ai_detection_loop(self):
        # Workers start both loops together in reload/start_camera.
        self.reload()

    def reload(self):
        db = SessionLocal()
        try:
            ids = [
                row[0]
                for row in (
                    db.query(Camera.device_id)
                    .join(Device, Device.id == Camera.device_id)
                    .filter(Device.enabled.is_(True))
                    .all()
                )
            ]
        finally:
            db.close()

        if not ids and not self._workers:
            self.start_camera(0)
            return

        for camera_id in ids:
            self.start_camera(camera_id)
        for camera_id in set(self._workers) - set(ids):
            self.stop_camera(camera_id)

    def start_camera(self, camera_id: int):
        fallback = None
        with self._lock:
            if camera_id in self._workers:
                return self._workers[camera_id]
            if camera_id != 0:
                fallback = self._workers.pop(0, None)
            worker = CameraService(camera_device_id=camera_id)
            self._workers[camera_id] = worker
        if fallback is not None:
            fallback.stop()
        worker.start_camera_loop()
        worker.start_ai_detection_loop()
        return worker

    def restart_camera(self, camera_id: int, enabled: bool = True):
        self.stop_camera(camera_id)
        if enabled:
            self.start_camera(camera_id)

    def stop_camera(self, camera_id: int):
        with self._lock:
            worker = self._workers.pop(camera_id, None)
        if worker is not None:
            worker.stop()

    def generate_frames(self, camera_id: int | None = None):
        worker = self._worker(camera_id)
        if worker is None:
            return iter(())
        return worker.generate_frames()

    def get_runtime_status(self, camera_id: int | None = None) -> dict:
        worker = self._worker(camera_id)
        if worker is None:
            return {
                "camera_online": False,
                "ai_detection_active": False,
                "camera_running": False,
                "ai_loop_running": False,
                "has_latest_frame": False,
                "last_detection_time": None,
            }
        return worker.get_runtime_status()

    def _worker(self, camera_id: int | None):
        with self._lock:
            if camera_id is not None:
                return self._workers.get(camera_id)
            return next(iter(self._workers.values()), None)
