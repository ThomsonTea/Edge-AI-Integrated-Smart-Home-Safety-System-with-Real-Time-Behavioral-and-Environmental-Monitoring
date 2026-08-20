import base64
import hashlib
import os

from cryptography.fernet import Fernet, InvalidToken


def _cipher() -> Fernet:
    configured = os.getenv("CAMERA_CREDENTIAL_KEY", "").strip()
    if configured:
        key = configured.encode("utf-8")
    else:
        secret = os.getenv("TOKEN_SECRET_KEY", "development-camera-key")
        key = base64.urlsafe_b64encode(hashlib.sha256(secret.encode("utf-8")).digest())
    return Fernet(key)


def encrypt_password(password: str | None) -> str | None:
    if not password:
        return None
    return _cipher().encrypt(password.encode("utf-8")).decode("utf-8")


def decrypt_password(value: str | None) -> str | None:
    if not value:
        return None
    try:
        return _cipher().decrypt(value.encode("utf-8")).decode("utf-8")
    except (InvalidToken, ValueError):
        return None
