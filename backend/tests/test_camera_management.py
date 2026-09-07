import os
import unittest
from unittest.mock import MagicMock, patch

from fastapi import HTTPException

from app.api.dev.api import api_router
from app.api.dev.endpoints.camera import _connection_url, camera_video_feed
from app.services.camera_manager import CameraManager
from app.services.camera_credentials import decrypt_password, encrypt_password
from app.services.camera_discovery import ONVIFConnectionError, resolve_onvif_stream


class CameraManagementTests(unittest.TestCase):
    def test_camera_routes_are_registered(self):
        paths = {getattr(route, "path", None) for route in api_router.routes}
        self.assertIn("/camera", paths)
        self.assertIn("/camera/test-connection", paths)
        self.assertIn("/camera/discover", paths)
        self.assertIn("/camera/resolve-stream", paths)
        self.assertIn("/camera/{camera_id}/video_feed", paths)

    def test_credentials_are_encoded_into_runtime_url(self):
        url = _connection_url("rtsp://10.0.0.2/stream", "front door", "p@ss:word")
        self.assertEqual(url, "rtsp://front%20door:p%40ss%3Aword@10.0.0.2/stream")

    def test_invalid_stream_url_is_rejected(self):
        with self.assertRaises(HTTPException):
            _connection_url("file:///etc/passwd", None, None)

    def test_embedded_credentials_are_rejected(self):
        with self.assertRaises(HTTPException):
            _connection_url("rtsp://user:password@10.0.0.2/stream", None, None)

    def test_camera_password_round_trip_is_encrypted(self):
        previous = os.environ.get("TOKEN_SECRET_KEY")
        os.environ["TOKEN_SECRET_KEY"] = "camera-test-secret"
        try:
            encrypted = encrypt_password("secret-password")
            self.assertNotEqual(encrypted, "secret-password")
            self.assertEqual(decrypt_password(encrypted), "secret-password")
        finally:
            if previous is None:
                os.environ.pop("TOKEN_SECRET_KEY", None)
            else:
                os.environ["TOKEN_SECRET_KEY"] = previous

    def test_camera_manager_forwards_viewer_skeleton_preference(self):
        manager = CameraManager()
        worker = MagicMock()
        frames = iter((b"frame",))
        worker.generate_frames.return_value = frames
        manager._workers[5] = worker

        result = manager.generate_frames(5, show_pose_skeleton=False)

        self.assertIs(result, frames)
        worker.generate_frames.assert_called_once_with(
            show_pose_skeleton=False,
        )

    @patch("app.api.dev.endpoints.camera.camera_service.generate_frames")
    @patch("app.api.dev.endpoints.camera.camera_service.start_camera")
    @patch("app.api.dev.endpoints.camera._camera_or_404")
    @patch("app.api.dev.endpoints.camera._current_profile")
    def test_camera_feed_passes_viewer_skeleton_preference(
        self,
        current_profile,
        camera_or_404,
        start_camera,
        generate_frames,
    ):
        current_profile.return_value = MagicMock(premise_id=1)
        camera_or_404.return_value = MagicMock(
            device=MagicMock(enabled=True),
        )
        generate_frames.return_value = iter(())

        camera_video_feed(
            camera_id=5,
            show_skeleton=False,
            db=MagicMock(),
            token={"user_id": 1},
        )

        start_camera.assert_called_once_with(5)
        generate_frames.assert_called_once_with(
            5,
            show_pose_skeleton=False,
        )

    @patch("app.services.camera_discovery.socket.create_connection")
    def test_unreachable_onvif_port_fails_fast(self, connect):
        connect.side_effect = TimeoutError("timed out")

        with self.assertRaises(ONVIFConnectionError):
            resolve_onvif_stream(
                "http://192.168.1.50:2020/onvif/device_service",
                "camera-user",
                "camera-password",
            )

        connect.assert_called_once_with(("192.168.1.50", 2020), timeout=3)

    @patch("app.services.camera_discovery.ONVIFCamera")
    @patch("app.services.camera_discovery.socket.create_connection")
    def test_onvif_resolution_uses_bounded_transport(self, connect, camera_type):
        connection = MagicMock()
        connect.return_value = connection
        profile = MagicMock(token="profile-token")
        media = MagicMock()
        media.GetProfiles.return_value = [profile]
        media.GetStreamUri.return_value = MagicMock(Uri="rtsp://192.168.1.50/stream1")
        camera_type.return_value.create_media_service.return_value = media

        result = resolve_onvif_stream(
            "http://192.168.1.50:2020/onvif/device_service",
            "camera-user",
            "camera-password",
        )

        self.assertEqual(result, "rtsp://192.168.1.50/stream1")
        connection.close.assert_called_once()
        transport = camera_type.call_args.kwargs["transport"]
        self.assertEqual(transport.load_timeout, 3)
        self.assertEqual(transport.operation_timeout, 5)


if __name__ == "__main__":
    unittest.main()
