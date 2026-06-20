import asyncio
import os
import unittest
from datetime import datetime
from types import SimpleNamespace
from unittest.mock import patch

from fastapi import HTTPException
from passlib.context import CryptContext

from app.api.dev.api import api_router
from app.api.dev.endpoints.ai_events import (
    TEST_EVENT_TYPES,
    _ensure_admin_if_role_exists,
)
from app.api.dev.endpoints.dashboard import _event_trend, _event_type_counts
from app.api.dev.endpoints.notifications_ws import _auth_close_reason
from app.services.profile_service import ProfileService
from app.services.face_service import FACE_LOGIN_THRESHOLD
from app.services.ai_event_service import create_ai_event
from app.services import notification_service
from app.services.behavioral_anomaly_service import (
    BehavioralAnomalyConfig,
    BehavioralAnomalyService,
    PoseSummary,
)
from app.services.notification_connection_manager import (
    NotificationConnectionManager,
)
from app.services.notification_service import broadcast_ai_event_once


class FakeWebSocket:
    def __init__(self, *, fail_on_send=False):
        self.accepted = False
        self.messages = []
        self.fail_on_send = fail_on_send

    async def accept(self):
        self.accepted = True

    async def send_json(self, payload):
        if self.fail_on_send:
            raise RuntimeError("stale connection")

        self.messages.append(payload)


class NotificationWebSocketTests(unittest.TestCase):
    def test_websocket_route_is_registered_under_dev_api_router(self):
        paths = {getattr(route, "path", None) for route in api_router.routes}

        self.assertIn("/ws/notifications", paths)

    def test_auth_routes_include_me_and_face_login(self):
        paths = {getattr(route, "path", None) for route in api_router.routes}

        self.assertIn("/me", paths)
        self.assertIn("/auth/face-login", paths)

    def test_dashboard_summary_route_is_registered(self):
        paths = {getattr(route, "path", None) for route in api_router.routes}

        self.assertIn("/dashboard/summary", paths)

    def test_profile_self_service_routes_are_registered(self):
        paths = {getattr(route, "path", None) for route in api_router.routes}

        self.assertIn("/profile/me", paths)
        self.assertIn("/profile/me/password", paths)
        self.assertIn("/profile/me/profile-picture", paths)
        self.assertIn("/profile/me/face", paths)

    def test_profile_response_derives_face_registered_from_signature(self):
        profile = SimpleNamespace(
            id=1,
            username="john",
            email="john@example.com",
            phone_number="123",
            group_type="Resident",
            premise_id=2,
            premise=SimpleNamespace(name="Default Home"),
            profile_image_path="/storage/profile_pictures/test.jpg",
            face_signature="{}",
            last_seen=None,
            is_blacklisted=False,
        )

        response = ProfileService(None).profile_response(profile)

        self.assertTrue(response["face_registered"])
        self.assertEqual(response["role"], "Resident")
        self.assertEqual(response["premise_name"], "Default Home")

    def test_profile_update_rejects_duplicate_username(self):
        class FakeQuery:
            def filter(self, *args):
                return self

            def first(self):
                return SimpleNamespace(id=2, username="taken")

        class FakeDb:
            def query(self, model):
                return FakeQuery()

        profile = SimpleNamespace(id=1, username="john")

        with self.assertRaises(HTTPException) as context:
            ProfileService(FakeDb()).update_current_profile(
                profile,
                username="taken",
            )

        self.assertEqual(context.exception.status_code, 400)

    def test_profile_update_allows_unchanged_username(self):
        class FakeQuery:
            def filter(self, *args):
                return self

            def first(self):
                return None

        class FakeDb:
            committed = False
            refreshed = False

            def query(self, model):
                return FakeQuery()

            def commit(self):
                self.committed = True

            def refresh(self, profile):
                self.refreshed = True

        profile = SimpleNamespace(
            id=1,
            username="john",
            email="old@example.com",
            phone_number="123",
        )
        db = FakeDb()

        updated = ProfileService(db).update_current_profile(
            profile,
            username="john",
            email="new@example.com",
            phone_number="456",
        )

        self.assertIs(updated, profile)
        self.assertEqual(profile.username, "john")
        self.assertEqual(profile.email, "new@example.com")
        self.assertEqual(profile.phone_number, "456")
        self.assertTrue(db.committed)
        self.assertTrue(db.refreshed)

    def test_change_password_requires_matching_confirmation(self):
        pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

        class FakeDb:
            pass

        profile = SimpleNamespace(hash_password=pwd_context.hash("oldpass"))

        with self.assertRaises(HTTPException) as context:
            ProfileService(FakeDb()).change_password(
                profile,
                current_password="oldpass",
                new_password="newpass",
                confirm_password="different",
            )

        self.assertEqual(context.exception.status_code, 400)

    def test_dashboard_event_type_counts_groups_other_alerts(self):
        events = [
            SimpleNamespace(event_type="known_person"),
            SimpleNamespace(event_type="unknown_person"),
            SimpleNamespace(event_type="blacklisted_person"),
            SimpleNamespace(event_type="gas_alert"),
        ]

        self.assertEqual(
            _event_type_counts(events),
            {
                "known_person": 1,
                "unknown_person": 1,
                "blacklisted_person": 1,
                "other": 1,
            },
        )

    def test_dashboard_event_trend_counts_by_day(self):
        events = [
            SimpleNamespace(timestamp=datetime(2026, 6, 13, 1, 0, 0)),
            SimpleNamespace(timestamp=datetime(2026, 6, 13, 2, 0, 0)),
            SimpleNamespace(timestamp=datetime(2026, 6, 12, 1, 0, 0)),
        ]

        self.assertEqual(
            _event_trend(events, "all"),
            [
                {"label": "2026-06-12", "count": 1},
                {"label": "2026-06-13", "count": 2},
            ],
        )

    def test_face_login_uses_stricter_threshold_than_camera_recognition(self):
        self.assertGreaterEqual(FACE_LOGIN_THRESHOLD, 0.55)

    def test_auth_close_reason_identifies_expired_tokens(self):
        error = HTTPException(status_code=401, detail="Token expired")

        self.assertEqual(_auth_close_reason(error), "token_expired")

    def test_auth_close_reason_defaults_to_auth_failed(self):
        error = HTTPException(status_code=401, detail="Invalid token")

        self.assertEqual(_auth_close_reason(error), "auth_failed")

    def test_send_to_premise_only_sends_matching_connections(self):
        async def run_test():
            manager = NotificationConnectionManager()
            premise_one = FakeWebSocket()
            premise_two = FakeWebSocket()

            await manager.connect(premise_one, 1)
            await manager.connect(premise_two, 2)
            await manager.send_to_premise(1, {"id": 7, "premise_id": 1})

            self.assertEqual(premise_one.messages, [{"id": 7, "premise_id": 1}])
            self.assertEqual(premise_two.messages, [])

        asyncio.run(run_test())

    def test_stale_connections_are_removed_after_send_failure(self):
        async def run_test():
            manager = NotificationConnectionManager()
            stale = FakeWebSocket(fail_on_send=True)
            healthy = FakeWebSocket()

            await manager.connect(stale, 1)
            await manager.connect(healthy, 1)
            await manager.send_to_premise(1, {"id": 8, "premise_id": 1})

            self.assertEqual(healthy.messages, [{"id": 8, "premise_id": 1}])
            self.assertNotIn(stale, manager._connections[1])

        asyncio.run(run_test())

    def test_broadcast_ai_event_once_dedupes_by_event_id(self):
        event = SimpleNamespace(
            id=42,
            event_type="unknown_person",
            premise_id=1,
            profile_id=None,
            confidence_score=None,
            timestamp=None,
            image_path=None,
        )

        notification_service._broadcasted_event_ids.clear()

        with patch.object(
            notification_service.notification_connection_manager,
            "broadcast_event_threadsafe",
        ) as broadcast:
            broadcast_ai_event_once(event)
            broadcast_ai_event_once(event)

        self.assertEqual(broadcast.call_count, 1)

    def test_blacklisted_person_is_critical_priority(self):
        self.assertEqual(
            notification_service.priority_for_event_type("blacklisted_person"),
            "Critical",
        )

    def test_behavior_emergency_events_are_critical_priority(self):
        self.assertEqual(
            notification_service.priority_for_event_type("fall_detected"),
            "Critical",
        )
        self.assertEqual(
            notification_service.priority_for_event_type("prolonged_inactivity"),
            "Critical",
        )

    def test_behavior_detector_confirms_fall_after_confirmation_time(self):
        detector = BehavioralAnomalyService(
            BehavioralAnomalyConfig(
                enabled=True,
                fall_confirm_seconds=4,
                inactivity_seconds=60,
                emergency_cooldown_seconds=120,
            )
        )
        frame_shape = (100, 100, 3)
        horizontal_bbox = (10, 40, 90, 70)

        self.assertIsNone(
            detector.process_person_bbox(
                bbox=horizontal_bbox,
                frame_shape=frame_shape,
                confidence=0.8,
                now=0,
            )
        )

        result = detector.process_person_bbox(
            bbox=horizontal_bbox,
            frame_shape=frame_shape,
            confidence=0.8,
            now=4.1,
        )

        self.assertIsNotNone(result)
        self.assertEqual(result.event_type, "fall_detected")
        self.assertEqual(result.confidence_score, 80.0)

    def test_behavior_detector_confirms_inactivity_after_threshold(self):
        detector = BehavioralAnomalyService(
            BehavioralAnomalyConfig(
                enabled=True,
                fall_confirm_seconds=4,
                inactivity_seconds=10,
                emergency_cooldown_seconds=120,
            )
        )
        frame_shape = (100, 100, 3)
        upright_bbox = (40, 10, 60, 90)

        self.assertIsNone(
            detector.process_person_bbox(
                bbox=upright_bbox,
                frame_shape=frame_shape,
                confidence=0.75,
                now=0,
            )
        )

        result = detector.process_person_bbox(
            bbox=upright_bbox,
            frame_shape=frame_shape,
            confidence=0.75,
            now=10.1,
        )

        self.assertIsNotNone(result)
        self.assertEqual(result.event_type, "prolonged_inactivity")
        self.assertEqual(result.confidence_score, 75.0)

    def test_behavior_detector_prevents_duplicate_active_anomaly(self):
        detector = BehavioralAnomalyService(
            BehavioralAnomalyConfig(
                enabled=True,
                fall_confirm_seconds=1,
                inactivity_seconds=60,
                emergency_cooldown_seconds=120,
            )
        )
        frame_shape = (100, 100, 3)
        horizontal_bbox = (10, 40, 90, 70)

        detector.process_person_bbox(
            bbox=horizontal_bbox,
            frame_shape=frame_shape,
            confidence=0.8,
            now=0,
        )

        first_result = detector.process_person_bbox(
            bbox=horizontal_bbox,
            frame_shape=frame_shape,
            confidence=0.8,
            now=1.1,
        )
        duplicate_result = detector.process_person_bbox(
            bbox=horizontal_bbox,
            frame_shape=frame_shape,
            confidence=0.8,
            now=2.0,
        )

        self.assertIsNotNone(first_result)
        self.assertIsNone(duplicate_result)

    def test_behavior_detector_defaults_mediapipe_pose_off(self):
        with patch.dict(os.environ, {}, clear=True):
            config = BehavioralAnomalyConfig()

        self.assertFalse(config.enable_mediapipe_pose)

    def test_behavior_detector_falls_back_when_mediapipe_import_fails(self):
        detector = BehavioralAnomalyService(
            BehavioralAnomalyConfig(
                enabled=True,
                enable_mediapipe_pose=True,
                pose_process_every_n_frames=1,
                pose_min_interval_seconds=0,
                fall_confirm_seconds=1,
                inactivity_seconds=60,
                emergency_cooldown_seconds=120,
            )
        )
        frame_shape = (100, 100, 3)
        horizontal_bbox = (10, 40, 90, 70)

        with patch(
            "app.services.behavioral_anomaly_service.import_module",
            side_effect=ImportError("missing mediapipe"),
        ):
            detector.process_person_bbox(
                bbox=horizontal_bbox,
                frame_shape=frame_shape,
                confidence=0.8,
                frame=object(),
                now=0,
            )
            result = detector.process_person_bbox(
                bbox=horizontal_bbox,
                frame_shape=frame_shape,
                confidence=0.8,
                frame=object(),
                now=1.1,
            )

        self.assertIsNotNone(result)
        self.assertEqual(result.event_type, "fall_detected")

    def test_behavior_detector_falls_back_when_mediapipe_solutions_missing(self):
        detector = BehavioralAnomalyService(
            BehavioralAnomalyConfig(
                enabled=True,
                enable_mediapipe_pose=True,
                pose_process_every_n_frames=1,
                pose_min_interval_seconds=0,
                fall_confirm_seconds=1,
                inactivity_seconds=60,
                emergency_cooldown_seconds=120,
            )
        )
        fake_mediapipe = SimpleNamespace(__version__="0.0-test")
        frame_shape = (100, 100, 3)
        horizontal_bbox = (10, 40, 90, 70)

        with patch(
            "app.services.behavioral_anomaly_service.import_module",
            return_value=fake_mediapipe,
        ):
            detector.process_person_bbox(
                bbox=horizontal_bbox,
                frame_shape=frame_shape,
                confidence=0.8,
                frame=object(),
                now=0,
            )
            result = detector.process_person_bbox(
                bbox=horizontal_bbox,
                frame_shape=frame_shape,
                confidence=0.8,
                frame=object(),
                now=1.1,
            )

        self.assertIsNotNone(result)
        self.assertEqual(result.event_type, "fall_detected")

    def test_pose_summary_confirms_fall_after_confirmation_time(self):
        detector = BehavioralAnomalyService(
            BehavioralAnomalyConfig(
                enabled=True,
                enable_mediapipe_pose=True,
                fall_confirm_seconds=2,
                inactivity_seconds=60,
                emergency_cooldown_seconds=120,
            )
        )
        fallen_pose = PoseSummary(
            body_center=(0.5, 0.7),
            nose_y=0.66,
            shoulder_y=0.7,
            hip_y=0.72,
            torso_angle_degrees=10,
            visibility_score=0.9,
        )

        self.assertIsNone(
            detector._process_pose_summary(
                summary=fallen_pose,
                confidence=0.9,
                current_time=0,
            )
        )

        result = detector._process_pose_summary(
            summary=fallen_pose,
            confidence=0.9,
            current_time=2.1,
        )

        self.assertIsNotNone(result)
        self.assertEqual(result.event_type, "fall_detected")

    def test_pose_summary_confirms_inactivity_after_threshold(self):
        detector = BehavioralAnomalyService(
            BehavioralAnomalyConfig(
                enabled=True,
                enable_mediapipe_pose=True,
                fall_confirm_seconds=2,
                inactivity_seconds=10,
                emergency_cooldown_seconds=120,
            )
        )
        upright_pose = PoseSummary(
            body_center=(0.5, 0.42),
            nose_y=0.18,
            shoulder_y=0.34,
            hip_y=0.56,
            torso_angle_degrees=88,
            visibility_score=0.9,
        )

        self.assertIsNone(
            detector._process_pose_summary(
                summary=upright_pose,
                confidence=0.85,
                current_time=0,
            )
        )

        result = detector._process_pose_summary(
            summary=upright_pose,
            confidence=0.85,
            current_time=10.1,
        )

        self.assertIsNotNone(result)
        self.assertEqual(result.event_type, "prolonged_inactivity")

    def test_notification_payload_includes_profile_and_confidence(self):
        event = SimpleNamespace(
            id=9,
            event_type="known_person",
            premise_id=1,
            profile_id=3,
            confidence_score=87.5,
            timestamp=None,
            image_path="/storage/alerts/test.jpg",
        )

        payload = notification_service.notification_payload_for_event(event)

        self.assertEqual(payload["profile_id"], 3)
        self.assertEqual(payload["confidence_score"], 87.5)

    def test_manual_test_event_types_are_limited_to_face_event_types(self):
        self.assertEqual(
            TEST_EVENT_TYPES,
            {"known_person", "unknown_person", "blacklisted_person"},
        )

    def test_manual_test_endpoint_allows_missing_role_for_legacy_tokens(self):
        _ensure_admin_if_role_exists({"user_id": 1})

    def test_manual_test_endpoint_rejects_non_admin_role(self):
        with self.assertRaises(HTTPException) as context:
            _ensure_admin_if_role_exists({"user_id": 1, "role": "Member"})

        self.assertEqual(context.exception.status_code, 403)

    def test_create_ai_event_commits_and_broadcasts_once(self):
        class FakeDb:
            def __init__(self):
                self.added_event = None
                self.committed = False
                self.refreshed = False

            def add(self, event):
                self.added_event = event

            def commit(self):
                self.committed = True

            def refresh(self, event):
                event.id = 101
                event.timestamp = None
                self.refreshed = True

        notification_service._broadcasted_event_ids.clear()
        db = FakeDb()

        with patch.object(
            notification_service.notification_connection_manager,
            "broadcast_event_threadsafe",
        ) as broadcast:
            event = create_ai_event(
                db,
                premise_id=1,
                profile_id=2,
                event_type="known_person",
                confidence_score=92.0,
                image_path="/storage/alerts/test.jpg",
            )

        self.assertIs(db.added_event, event)
        self.assertTrue(db.committed)
        self.assertTrue(db.refreshed)
        self.assertEqual(event.id, 101)
        self.assertEqual(event.event_type, "known_person")
        self.assertEqual(event.profile_id, 2)
        self.assertEqual(broadcast.call_count, 1)


if __name__ == "__main__":
    unittest.main()
