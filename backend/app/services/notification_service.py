from datetime import datetime
import threading
from typing import Any

from app.models.event import AIEvent
from app.services.notification_connection_manager import (
    notification_connection_manager,
)


_broadcasted_event_ids: set[int] = set()
_broadcast_lock = threading.Lock()


CRITICAL_EVENTS = {
    "blacklisted_person",
    "fire_alert",
    "gas_alert",
    "system_error",
    "fall_detected",
    "prolonged_inactivity",
}

WARNING_EVENTS = {
    "unknown_person",
    "camera_offline",
}


def priority_for_event_type(event_type: str | None) -> str:
    if event_type in CRITICAL_EVENTS:
        return "Critical"

    if event_type in WARNING_EVENTS:
        return "Warning"

    return "Info"


def message_for_event_type(event_type: str | None) -> str:
    return {
        "known_person": "Known person detected.",
        "unknown_person": "Unknown person detected at your premise.",
        "blacklisted_person": "Blacklisted person detected. Immediate attention required.",
        "fire_alert": "Fire alert detected. Check your premise immediately.",
        "gas_alert": "Gas alert detected. Check your premise immediately.",
        "camera_offline": "Camera is offline.",
        "system_error": "System error detected.",
        "fall_detected": "Possible fall detected. Check your premise immediately.",
        "prolonged_inactivity": "Possible prolonged inactivity detected. Check your premise immediately.",
    }.get(event_type or "", "New security event detected.")


def notification_payload_for_event(event: AIEvent) -> dict[str, Any]:
    event_type = event.event_type or "unknown"
    timestamp = event.timestamp
    confidence_score = event.confidence_score

    if isinstance(timestamp, datetime):
        timestamp_value = timestamp.isoformat()
    else:
        timestamp_value = None

    return {
        "id": event.id,
        "event_type": event_type,
        "premise_id": event.premise_id,
        "profile_id": event.profile_id,
        "confidence_score": (
            float(confidence_score) if confidence_score is not None else None
        ),
        "timestamp": timestamp_value,
        "image_path": event.image_path,
        "priority": priority_for_event_type(event_type),
        "message": message_for_event_type(event_type),
    }


def broadcast_ai_event_once(event: AIEvent) -> None:
    if event.id is None:
        return

    with _broadcast_lock:
        if event.id in _broadcasted_event_ids:
            print(f"ℹ️ AI event broadcast skipped: duplicate id={event.id}")
            return

        _broadcasted_event_ids.add(event.id)

    payload = notification_payload_for_event(event)
    notification_connection_manager.broadcast_event_threadsafe(payload)
    print(
        "📣 AI event broadcast queued: "
        f"id={event.id} "
        f"type={event.event_type} "
        f"premise_id={event.premise_id}"
    )
