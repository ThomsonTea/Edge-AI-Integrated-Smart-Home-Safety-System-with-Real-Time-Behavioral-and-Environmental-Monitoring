import asyncio
import threading
from collections import defaultdict
from typing import Any

from fastapi import WebSocket


class NotificationConnectionManager:
    def __init__(self):
        self._connections: dict[int, set[WebSocket]] = defaultdict(set)
        self._lock = threading.Lock()
        self._loop: asyncio.AbstractEventLoop | None = None

    async def connect(self, websocket: WebSocket, premise_id: int) -> None:
        await websocket.accept()
        self._loop = asyncio.get_running_loop()

        with self._lock:
            self._connections[premise_id].add(websocket)

    def disconnect(self, websocket: WebSocket, premise_id: int) -> None:
        with self._lock:
            connections = self._connections.get(premise_id)
            if connections is None:
                return

            connections.discard(websocket)
            if not connections:
                self._connections.pop(premise_id, None)

    async def send_to_premise(
        self,
        premise_id: int,
        payload: dict[str, Any],
    ) -> None:
        with self._lock:
            connections = list(self._connections.get(premise_id, set()))

        stale_connections = []

        for websocket in connections:
            try:
                await websocket.send_json(payload)
            except Exception:
                stale_connections.append(websocket)

        for websocket in stale_connections:
            self.disconnect(websocket, premise_id)

    async def broadcast_event(self, payload: dict[str, Any]) -> None:
        premise_id = payload.get("premise_id")

        if premise_id is None:
            return

        await self.send_to_premise(int(premise_id), payload)

    def broadcast_event_threadsafe(self, payload: dict[str, Any]) -> None:
        loop = self._loop

        if loop is None or loop.is_closed():
            return

        asyncio.run_coroutine_threadsafe(self.broadcast_event(payload), loop)


notification_connection_manager = NotificationConnectionManager()
