import asyncio
import unittest
from types import SimpleNamespace
from unittest.mock import patch

from fastapi import HTTPException

from app.api.dev.api import api_router
from app.api.dev.endpoints.ai_events import (
    TEST_EVENT_TYPES,
    _ensure_admin_if_role_exists,
)
from app.api.dev.endpoints.notifications_ws import _auth_close_reason
from app.services.ai_event_service import create_ai_event
from app.services import notification_service
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
