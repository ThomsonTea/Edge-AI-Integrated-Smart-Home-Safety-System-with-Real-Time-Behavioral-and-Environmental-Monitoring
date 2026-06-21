# WebSocket Notifications

## Runtime Path

The notification WebSocket is mounted under the existing development API prefix:

```text
/api/dev/ws/notifications?token=<JWT>
```

The Flutter app derives this from `AppConfig.apiBaseUrl`, so
`https://api.philous.me/api/dev` becomes:

```text
wss://api.philous.me/api/dev/ws/notifications?token=<JWT>
```

## Raspberry Pi Deployment

This implementation is intended for the FYP Raspberry Pi demo deployment with a
single Uvicorn worker:

```bash
uvicorn app.main:app --host 0.0.0.0 --port 8000 --workers 1
```

Keep `--workers 1`. The in-memory WebSocket connection manager and notification
broadcast idempotency guard are process-local. Multiple workers would need a
shared broker such as Redis pub/sub, which is intentionally out of scope.

## Reverse Proxy Settings

If Nginx or another reverse proxy fronts the Pi, it must preserve WebSocket
upgrade headers and use a long read timeout:

```nginx
location /api/dev/ws/notifications {
    proxy_pass http://127.0.0.1:8000;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_read_timeout 3600s;
    proxy_send_timeout 3600s;
}
```

REST endpoints continue to use normal JWT `Authorization: Bearer <token>`
headers. The WebSocket endpoint uses the query parameter token because browsers
and mobile WebSocket clients do not consistently support custom headers during
the upgrade handshake.
