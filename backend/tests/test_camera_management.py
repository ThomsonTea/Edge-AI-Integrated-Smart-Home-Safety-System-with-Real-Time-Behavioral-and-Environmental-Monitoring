import os
import unittest

from fastapi import HTTPException

from app.api.dev.api import api_router
from app.api.dev.endpoints.camera import _connection_url
from app.services.camera_credentials import decrypt_password, encrypt_password


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


if __name__ == "__main__":
    unittest.main()
