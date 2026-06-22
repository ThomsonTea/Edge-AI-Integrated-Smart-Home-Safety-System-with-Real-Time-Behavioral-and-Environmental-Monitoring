import unittest
from datetime import datetime, timezone
from unittest.mock import patch

from app.api.dev.api import api_router
from app.services.sensor_service import SensorService


class SensorServiceTests(unittest.TestCase):
    def test_sensor_latest_route_is_registered(self):
        paths = {getattr(route, "path", None) for route in api_router.routes}

        self.assertIn("/sensors/latest", paths)

    def test_parse_json_line(self):
        parsed = SensorService.parse_line(
            '{"temperature":28.5,"humidity":70.2,"gas":320}'
        )

        self.assertEqual(
            parsed,
            {
                "temperature": 28.5,
                "humidity": 70.2,
                "gas": 320.0,
            },
        )

    def test_parse_comma_line(self):
        parsed = SensorService.parse_line(
            "temperature=28.5,humidity=70.2,gas=320"
        )

        self.assertEqual(
            parsed,
            {
                "temperature": 28.5,
                "humidity": 70.2,
                "gas": 320.0,
            },
        )

    def test_parse_bad_line_returns_none(self):
        self.assertIsNone(SensorService.parse_line("hello from arduino"))

    def test_update_from_invalid_line_keeps_previous_values(self):
        service = SensorService(enabled=False)
        self.assertTrue(
            service.update_from_line("temperature=28.5,humidity=70.2,gas=320")
        )
        before = service.get_latest()

        self.assertFalse(service.update_from_line("bad line"))
        after = service.get_latest()

        self.assertEqual(after["temperature"], before["temperature"])
        self.assertEqual(after["humidity"], before["humidity"])
        self.assertEqual(after["gas"], before["gas"])
        self.assertEqual(after["last_updated"], before["last_updated"])

    def test_disabled_service_does_not_start_reader(self):
        service = SensorService(enabled=False)
        service.start()

        self.assertEqual(service.get_latest()["status"], "disabled")

    def test_latest_formats_timestamp_as_utc_z(self):
        service = SensorService(enabled=False)
        with service._lock:
            service._latest["last_updated"] = datetime(
                2026, 6, 22, 12, 0, tzinfo=timezone.utc
            )

        self.assertEqual(
            service.get_latest()["last_updated"],
            "2026-06-22T12:00:00Z",
        )

    def test_env_defaults_can_disable_service(self):
        with patch.dict("os.environ", {"ENABLE_SENSOR_SERVICE": "false"}):
            service = SensorService()

        self.assertFalse(service.enabled)
        self.assertEqual(service.get_latest()["status"], "disabled")


if __name__ == "__main__":
    unittest.main()
