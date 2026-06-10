import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import cv2
import numpy as np
from insightface.app import FaceAnalysis
from sqlalchemy.orm import Session

from app.models.profile import Profile


FACE_MODEL_NAME = "insightface.buffalo_l"
FACE_EMBEDDING_DIMENSION = 512
MODEL_ROOT = Path(__file__).resolve().parents[2] / "models" / "insightface"


class FaceRegistrationError(ValueError):
    """Raised when a face cannot be registered from the provided image."""


class FaceService:
    _face_app: FaceAnalysis | None = None

    def __init__(self, db: Session):
        self.db = db
        self.face_app = self._get_face_app()

    def register_face_for_profile(
        self,
        profile_id: int,
        image_bytes: bytes,
    ) -> Profile:
        profile = self.db.query(Profile).filter(Profile.id == profile_id).first()

        if profile is None:
            raise FaceRegistrationError("Profile not found.")

        image = self.decode_image(image_bytes)
        embedding = self.generate_embedding(image)
        profile.face_signature = self.serialize_embedding(embedding)

        self.db.commit()
        self.db.refresh(profile)

        return profile

    def decode_image(self, image_bytes: bytes) -> np.ndarray:
        if not image_bytes:
            raise FaceRegistrationError("Image file is empty.")

        buffer = np.frombuffer(image_bytes, dtype=np.uint8)
        image = cv2.imdecode(buffer, cv2.IMREAD_COLOR)

        if image is None:
            raise FaceRegistrationError("Uploaded file is not a valid image.")

        return image

    def generate_embedding(self, image: np.ndarray) -> list[float]:
        faces = self.face_app.get(image)

        if not faces:
            raise FaceRegistrationError("No face detected in image.")

        if len(faces) > 1:
            raise FaceRegistrationError("Multiple faces detected in image.")

        embedding = faces[0].embedding

        if embedding is None:
            raise FaceRegistrationError("Face embedding could not be generated.")

        values = np.asarray(embedding, dtype=np.float32).tolist()

        if len(values) != FACE_EMBEDDING_DIMENSION:
            raise FaceRegistrationError(
                f"Unexpected embedding dimension: {len(values)}."
            )

        return [float(value) for value in values]

    def serialize_embedding(self, embedding: list[float]) -> str:
        payload: dict[str, Any] = {
            "model": FACE_MODEL_NAME,
            "dimension": len(embedding),
            "embedding": embedding,
            "registered_at": datetime.now(timezone.utc).isoformat(),
        }

        return json.dumps(payload, separators=(",", ":"))

    @classmethod
    def _get_face_app(cls) -> FaceAnalysis:
        if cls._face_app is None:
            MODEL_ROOT.mkdir(parents=True, exist_ok=True)
            app = FaceAnalysis(name="buffalo_l", root=str(MODEL_ROOT))
            app.prepare(ctx_id=-1, det_size=(640, 640))
            cls._face_app = app

        return cls._face_app
