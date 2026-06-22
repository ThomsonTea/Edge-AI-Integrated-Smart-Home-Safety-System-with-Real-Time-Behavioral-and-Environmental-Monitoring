import unittest
from datetime import datetime, timedelta, timezone
from unittest.mock import patch

from app.api.dev.api import api_router
from app.models.event import AIEvent
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

    def refresh(self, model):
        if isinstance(model, AIEvent):
            model.id = len(self.added)
            if model.timestamp is None:
                model.timestamp = datetime.now(timezone.utc)


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

    def test_save_interval_defaults_to_sixty_seconds(self):
        with patch.dict("os.environ", {}, clear=True):
            service = SensorService(enabled=False, premise_id=1)

        self.assertEqual(service._save_interval_seconds, 60)

    def test_save_interval_reads_environment_override(self):
        with patch.dict("os.environ", {"SENSOR_SAVE_INTERVAL_SECONDS": "10"}):
            service = SensorService(enabled=False, premise_id=1)

        self.assertEqual(service._save_interval_seconds, 10)

    def test_invalid_save_interval_uses_default(self):
        with patch.dict("os.environ", {"SENSOR_SAVE_INTERVAL_SECONDS": "nope"}):
            service = SensorService(enabled=False, premise_id=1)

        self.assertEqual(service._save_interval_seconds, 60)

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
            save_interval_seconds=10,
        )
        service.update_from_line("temperature=30.7,humidity=70,gas=966")
        now = datetime(2026, 6, 22, 12, 0, tzinfo=timezone.utc)

        self.assertTrue(service._persist_latest_reading(now=now))
        self.assertFalse(
            service._persist_latest_reading(now=now + timedelta(seconds=9))
        )
        self.assertEqual(len(db.added), 1)

    def test_high_gas_creates_gas_alert(self):
        db = FakeDb()
        service = SensorService(
            enabled=True,
            premise_id=1,
            db_session_factory=lambda: db,
            gas_alert_threshold=900,
        )

        service.update_from_line("temperature=30,humidity=70,gas=966")

        events = [item for item in db.added if isinstance(item, AIEvent)]
        self.assertEqual(len(events), 1)
        self.assertEqual(events[0].event_type, "gas_alert")
        self.assertEqual(events[0].premise_id, 1)

    def test_high_temperature_creates_high_temperature_alert(self):
        db = FakeDb()
        service = SensorService(
            enabled=True,
            premise_id=1,
            db_session_factory=lambda: db,
            temperature_alert_threshold=40,
        )

        service.update_from_line("temperature=41.5,humidity=70,gas=300")

        events = [item for item in db.added if isinstance(item, AIEvent)]
        self.assertEqual(len(events), 1)
        self.assertEqual(events[0].event_type, "high_temperature")

    def test_environment_alerts_skip_missing_premise_id(self):
        db = FakeDb()
        service = SensorService(
            enabled=True,
            premise_id=1,
            db_session_factory=lambda: db,
            gas_alert_threshold=900,
        )
        service.premise_id = None

        service.update_from_line("temperature=30,humidity=70,gas=966")

        events = [item for item in db.added if isinstance(item, AIEvent)]
        self.assertEqual(events, [])

    def test_environment_alert_cooldown_prevents_duplicates(self):
        db = FakeDb()
        now = datetime(2026, 6, 22, 12, 0, tzinfo=timezone.utc)
        service = SensorService(
            enabled=True,
            premise_id=1,
            db_session_factory=lambda: db,
            environment_alert_cooldown_seconds=120,
        )

        self.assertTrue(
            service._create_environment_alert(
                "gas_alert",
                confidence_score=90,
                now=now,
            )
        )
        self.assertFalse(
            service._create_environment_alert(
                "gas_alert",
                confidence_score=95,
                now=now + timedelta(seconds=30),
            )
        )

        events = [item for item in db.added if isinstance(item, AIEvent)]
        self.assertEqual(len(events), 1)

    def test_environment_alert_cooldown_allows_after_elapsed(self):
        db = FakeDb()
        now = datetime(2026, 6, 22, 12, 0, tzinfo=timezone.utc)
        service = SensorService(
            enabled=True,
            premise_id=1,
            db_session_factory=lambda: db,
            environment_alert_cooldown_seconds=120,
        )

        service._create_environment_alert("gas_alert", confidence_score=90, now=now)
        service._create_environment_alert(
            "gas_alert",
            confidence_score=95,
            now=now + timedelta(seconds=121),
        )

        events = [item for item in db.added if isinstance(item, AIEvent)]
        self.assertEqual(len(events), 2)

    def test_disabled_service_does_not_create_environment_alerts(self):
        db = FakeDb()
        service = SensorService(
            enabled=False,
            premise_id=1,
            db_session_factory=lambda: db,
            gas_alert_threshold=900,
        )

        service.update_from_line("temperature=30,humidity=70,gas=966")

        events = [item for item in db.added if isinstance(item, AIEvent)]
        self.assertEqual(events, [])

    def test_sensor_offline_alert_waits_for_timeout(self):
        db = FakeDb()
        service = SensorService(
            enabled=True,
            premise_id=1,
            db_session_factory=lambda: db,
            sensor_offline_seconds=30,
        )
        now = datetime(2026, 6, 22, 12, 0, tzinfo=timezone.utc)

        service._evaluate_sensor_offline(now=now)
        service._evaluate_sensor_offline(now=now + timedelta(seconds=29))

        events = [item for item in db.added if isinstance(item, AIEvent)]
        self.assertEqual(events, [])

    def test_sensor_offline_alert_created_after_timeout(self):
        db = FakeDb()
        service = SensorService(
            enabled=True,
            premise_id=1,
            db_session_factory=lambda: db,
            sensor_offline_seconds=30,
        )
        now = datetime(2026, 6, 22, 12, 0, tzinfo=timezone.utc)

        service._evaluate_sensor_offline(now=now)
        service._evaluate_sensor_offline(now=now + timedelta(seconds=31))

        events = [item for item in db.added if isinstance(item, AIEvent)]
        self.assertEqual(len(events), 1)
        self.assertEqual(events[0].event_type, "sensor_offline")

    def test_connected_reading_clears_offline_timer(self):
        db = FakeDb()
        service = SensorService(
            enabled=True,
            premise_id=1,
            db_session_factory=lambda: db,
            sensor_offline_seconds=30,
        )
        now = datetime(2026, 6, 22, 12, 0, tzinfo=timezone.utc)
        service._evaluate_sensor_offline(now=now)

        service.update_from_line("temperature=30,humidity=70,gas=300")

        self.assertIsNone(service._disconnected_since)


if __name__ == "__main__":
    unittest.main()
