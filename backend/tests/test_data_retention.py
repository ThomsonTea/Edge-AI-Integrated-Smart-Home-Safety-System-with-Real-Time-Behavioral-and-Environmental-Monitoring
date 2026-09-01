import tempfile
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path
from unittest.mock import patch

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.api.dev.api import api_router
from app.db.database import Base
from app.models import AIEvent, Device, Premise, PremiseSetting, Sensor, SensorReading
from app.services.data_retention_service import cleanup_premise_data


class DataRetentionTests(unittest.TestCase):
    def setUp(self):
        self.engine = create_engine(
            "sqlite://",
            connect_args={"check_same_thread": False},
            poolclass=StaticPool,
        )
        Base.metadata.create_all(self.engine)
        self.Session = sessionmaker(bind=self.engine)
        self.db = self.Session()

    def tearDown(self):
        self.db.close()
        Base.metadata.drop_all(self.engine)
        self.engine.dispose()

    def test_retention_routes_are_registered(self):
        routes = {(getattr(route, "path", None), tuple(getattr(route, "methods", []))) for route in api_router.routes}
        self.assertTrue(any(path == "/premise/settings/retention" for path, _ in routes))
        self.assertTrue(any(path == "/premise/settings/retention/cleanup" for path, _ in routes))
        self.assertTrue(any(path == "/ai_events/{event_id}/pin" for path, _ in routes))

    def test_cleanup_deletes_only_expired_unprotected_premise_data(self):
        now = datetime(2026, 9, 1, tzinfo=timezone.utc)
        old = now - timedelta(days=91)
        recent = now - timedelta(days=1)

        self.db.add_all([Premise(id=1, name="Home"), Premise(id=2, name="Other")])
        settings = PremiseSetting(
            premise_id=1,
            event_retention_days=30,
            sensor_retention_days=30,
            image_retention_days=30,
            auto_delete_images=True,
            preserve_unacknowledged=True,
            preserve_critical=True,
        )
        self.db.add(settings)
        self.db.add_all(
            [
                AIEvent(id=1, premise_id=1, event_type="unknown_person", severity="high", timestamp=old, is_acknowledged=True, is_pinned=False, image_path="/storage/alerts/expired.jpg"),
                AIEvent(id=2, premise_id=1, event_type="unknown_person", severity="high", timestamp=old, is_acknowledged=True, is_pinned=True),
                AIEvent(id=3, premise_id=1, event_type="unknown_person", severity="high", timestamp=old, is_acknowledged=False, is_pinned=False),
                AIEvent(id=4, premise_id=1, event_type="fall_detected", severity="critical", timestamp=old, is_acknowledged=True, is_pinned=False),
                AIEvent(id=5, premise_id=1, event_type="known_person", severity="low", timestamp=recent, is_acknowledged=True, is_pinned=False),
                AIEvent(id=6, premise_id=2, event_type="unknown_person", severity="high", timestamp=old, is_acknowledged=True, is_pinned=False),
            ]
        )
        self.db.add(Device(id=10, premise_id=1, device_name="Sensor", device_type="sensor"))
        self.db.add(Sensor(device_id=10, sensor_type="environmental"))
        self.db.add_all(
            [
                SensorReading(id=100, sensor_id=10, recorded_at=old),
                SensorReading(id=101, sensor_id=10, recorded_at=recent),
            ]
        )
        self.db.commit()

        with tempfile.TemporaryDirectory() as temp_dir:
            alerts_dir = Path(temp_dir).resolve()
            expired_image = alerts_dir / "expired.jpg"
            expired_image.write_bytes(b"image")
            with patch("app.services.data_retention_service.ALERT_STORAGE_DIR", alerts_dir):
                result = cleanup_premise_data(self.db, settings, now=now, batch_size=2)

            self.assertFalse(expired_image.exists())

        self.assertEqual(result.events_deleted, 1)
        self.assertEqual(result.sensor_readings_deleted, 1)
        self.assertEqual(result.images_deleted, 1)
        self.assertEqual({event.id for event in self.db.query(AIEvent).all()}, {2, 3, 4, 5, 6})
        self.assertEqual({reading.id for reading in self.db.query(SensorReading).all()}, {101})

    def test_cleanup_never_deletes_image_outside_alert_storage(self):
        now = datetime(2026, 9, 1, tzinfo=timezone.utc)
        self.db.add(Premise(id=1, name="Home"))
        settings = PremiseSetting(premise_id=1, event_retention_days=30, sensor_retention_days=30)
        self.db.add(settings)

        with tempfile.TemporaryDirectory() as temp_dir:
            outside_file = Path(temp_dir) / "outside.jpg"
            outside_file.write_bytes(b"image")
            self.db.add(
                AIEvent(
                    id=1,
                    premise_id=1,
                    event_type="unknown_person",
                    severity="high",
                    timestamp=now - timedelta(days=31),
                    is_acknowledged=True,
                    is_pinned=False,
                    image_path=str(outside_file),
                )
            )
            self.db.commit()

            with tempfile.TemporaryDirectory() as alerts_temp:
                with patch("app.services.data_retention_service.ALERT_STORAGE_DIR", Path(alerts_temp).resolve()):
                    cleanup_premise_data(self.db, settings, now=now)

            self.assertTrue(outside_file.exists())


if __name__ == "__main__":
    unittest.main()
