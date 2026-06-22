import unittest
from datetime import datetime, timedelta, timezone
from unittest.mock import patch

from app.api.dev.api import api_router
from app.services.sensor_service import SensorService


class FakeDb:
    def __init__(self):
        self.added = []
        self.committed = False
        self.rolled_back = False
        self.closed = False

    def add(self, model):
        self.added.append(model)

    def commit(self):
        self.committed = True

    def rollback(self):
        self.rolled_back = True

    def close(self):
        self.closed = True


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

    def test_persist_latest_reading_saves_complete_connected_values(self):
        db = FakeDb()
        service = SensorService(
            enabled=False,
            premise_id=1,
            db_session_factory=lambda: db,
        )
        service.update_from_line('{"temperature":30.7,"humidity":70,"gas":966}')

        saved = service._persist_latest_reading(
            now=datetime(2026, 6, 22, 12, 0, tzinfo=timezone.utc)
        )

        self.assertTrue(saved)
        self.assertTrue(db.committed)
        self.assertTrue(db.closed)
        self.assertEqual(len(db.added), 1)
        reading = db.added[0]
        self.assertEqual(reading.premise_id, 1)
        self.assertEqual(str(reading.temperature), "30.7")
        self.assertEqual(str(reading.humidity), "70.0")
        self.assertEqual(reading.gas, 966)
        self.assertEqual(reading.sensor_status, "connected")

    def test_persist_latest_reading_skips_missing_premise_id(self):
        db = FakeDb()
        service = SensorService(
            enabled=False,
            premise_id=None,
            db_session_factory=lambda: db,
        )
        service.premise_id = None
        service.update_from_line("temperature=30.7,humidity=70,gas=966")

        self.assertFalse(service._persist_latest_reading())
        self.assertEqual(db.added, [])

    def test_persist_latest_reading_skips_disconnected_sensor(self):
        db = FakeDb()
        service = SensorService(
            enabled=False,
            premise_id=1,
            db_session_factory=lambda: db,
        )

        self.assertFalse(service._persist_latest_reading())
        self.assertEqual(db.added, [])

    def test_persist_latest_reading_skips_incomplete_sensor_values(self):
        db = FakeDb()
        service = SensorService(
            enabled=False,
            premise_id=1,
            db_session_factory=lambda: db,
        )
        with service._lock:
            service._latest.update(
                {
                    "status": "connected",
                    "temperature": 30.7,
                    "humidity": None,
                    "gas": 966,
                }
            )

        self.assertFalse(service._persist_latest_reading())
        self.assertEqual(db.added, [])

    def test_persist_latest_reading_throttles_to_save_interval(self):
        db = FakeDb()
        service = SensorService(
            enabled=False,
            premise_id=1,
            db_session_factory=lambda: db,
            save_interval_seconds=60,
        )
        service.update_from_line("temperature=30.7,humidity=70,gas=966")
        now = datetime(2026, 6, 22, 12, 0, tzinfo=timezone.utc)

        self.assertTrue(service._persist_latest_reading(now=now))
        self.assertFalse(
            service._persist_latest_reading(now=now + timedelta(seconds=59))
        )
        self.assertEqual(len(db.added), 1)


if __name__ == "__main__":
    unittest.main()
