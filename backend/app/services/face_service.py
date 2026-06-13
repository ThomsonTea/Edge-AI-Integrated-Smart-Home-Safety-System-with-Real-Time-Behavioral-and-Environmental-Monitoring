import json
import os
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import cv2
import numpy as np
from dotenv import load_dotenv
from insightface.app import FaceAnalysis
from sqlalchemy.orm import Session

from app.models.profile import Profile


load_dotenv()

FACE_MODEL_NAME = "insightface.buffalo_s"
FACE_EMBEDDING_DIMENSION = 512
DEFAULT_FACE_MATCH_THRESHOLD = 0.45
DEFAULT_FACE_LOGIN_THRESHOLD = 0.60
MODEL_ROOT = Path(__file__).resolve().parents[2] / "models" / "insightface"


def _read_face_match_threshold() -> float:
    raw_value = os.getenv("FACE_MATCH_THRESHOLD")

    if raw_value is None or raw_value.strip() == "":
        return DEFAULT_FACE_MATCH_THRESHOLD

    try:
        threshold = float(raw_value)
    except ValueError:
        print(
            "Invalid FACE_MATCH_THRESHOLD="
            f"{raw_value}; using {DEFAULT_FACE_MATCH_THRESHOLD:.2f}"
        )
        return DEFAULT_FACE_MATCH_THRESHOLD

    if threshold <= 0 or threshold >= 1:
        print(
            "FACE_MATCH_THRESHOLD should be between 0 and 1; "
            f"using {DEFAULT_FACE_MATCH_THRESHOLD:.2f}"
        )
        return DEFAULT_FACE_MATCH_THRESHOLD

    return threshold


FACE_MATCH_THRESHOLD = _read_face_match_threshold()


def _read_face_login_threshold() -> float:
    raw_value = os.getenv("FACE_LOGIN_THRESHOLD")

    if raw_value is None or raw_value.strip() == "":
        return DEFAULT_FACE_LOGIN_THRESHOLD

    try:
        threshold = float(raw_value)
    except ValueError:
        print(
            "Invalid FACE_LOGIN_THRESHOLD="
            f"{raw_value}; using {DEFAULT_FACE_LOGIN_THRESHOLD:.2f}"
        )
        return DEFAULT_FACE_LOGIN_THRESHOLD

    if threshold <= 0 or threshold >= 1:
        print(
            "FACE_LOGIN_THRESHOLD should be between 0 and 1; "
            f"using {DEFAULT_FACE_LOGIN_THRESHOLD:.2f}"
        )
        return DEFAULT_FACE_LOGIN_THRESHOLD

    return threshold


FACE_LOGIN_THRESHOLD = _read_face_login_threshold()


class FaceRegistrationError(ValueError):
    """Raised when a face cannot be registered from the provided image."""


class FaceRecognitionResult(dict):
    @classmethod
    def unknown(cls, confidence: float = 0.0) -> "FaceRecognitionResult":
        return cls(
            matched=False,
            profile_id=None,
            profile_name=None,
            confidence=float(confidence),
        )

    @classmethod
    def matched_profile(
        cls,
        profile: Profile,
        confidence: float,
    ) -> "FaceRecognitionResult":
        return cls(
            matched=True,
            profile_id=profile.id,
            profile_name=profile.username,
            confidence=float(confidence),
        )


class FaceLoginError(ValueError):
    """Raised when face login cannot authenticate a profile."""


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

    def generate_login_embedding(self, image: np.ndarray) -> tuple[list[float], int]:
        faces = self.face_app.get(image)
        face_count = len(faces)
        print(f"Face login detected face count: {face_count}")

        if face_count == 0:
            raise FaceLoginError("No face detected in image.")

        if face_count > 1:
            raise FaceLoginError("Multiple faces detected in image.")

        embedding = faces[0].embedding

        if embedding is None:
            raise FaceLoginError("Face embedding could not be generated.")

        values = np.asarray(embedding, dtype=np.float32).tolist()

        if len(values) != FACE_EMBEDDING_DIMENSION:
            raise FaceLoginError(f"Unexpected embedding dimension: {len(values)}.")

        return [float(value) for value in values], face_count

    def serialize_embedding(self, embedding: list[float]) -> str:
        payload: dict[str, Any] = {
            "model": FACE_MODEL_NAME,
            "dimension": len(embedding),
            "embedding": embedding,
            "registered_at": datetime.now(timezone.utc).isoformat(),
        }

        return json.dumps(payload, separators=(",", ":"))

    def deserialize_embedding(
        self,
        face_signature: str,
        *,
        require_current_model: bool = False,
    ) -> list[float]:
        try:
            payload = json.loads(face_signature)
        except (TypeError, json.JSONDecodeError):
            raise FaceRegistrationError("Stored face signature is not valid JSON.")

        if not isinstance(payload, dict):
            raise FaceRegistrationError("Stored face signature has invalid format.")

        model = payload.get("model")
        if require_current_model and model != FACE_MODEL_NAME:
            raise FaceLoginError(
                "Stored face signature model mismatch: "
                f"{model or 'unknown'} != {FACE_MODEL_NAME}."
            )

        embedding = payload.get("embedding")

        if not isinstance(embedding, list) or not embedding:
            raise FaceRegistrationError("Stored face signature has no embedding.")

        values = [float(value) for value in embedding]

        if len(values) != FACE_EMBEDDING_DIMENSION:
            raise FaceRegistrationError(
                f"Stored embedding has unexpected dimension: {len(values)}."
            )

        return values

    def load_login_profiles(self, db: Session) -> list[Profile]:
        return db.query(Profile).filter(Profile.face_signature.isnot(None)).all()

    def recognize_face_for_login(
        self,
        image: np.ndarray,
        db: Session,
    ) -> Profile:
        try:
            probe_embedding, _ = self.generate_login_embedding(image)
        except FaceLoginError as error:
            self._log_face_login_decision(
                best_profile_id=None,
                best_score=0.0,
                accepted=False,
                reason=str(error),
            )
            raise

        best_profile = None
        best_score = 0.0
        model_mismatch_count = 0

        for profile in self.load_login_profiles(db):
            try:
                registered_embedding = self.deserialize_embedding(
                    profile.face_signature,
                    require_current_model=True,
                )
            except FaceLoginError as error:
                model_mismatch_count += 1
                print(f"Face login skipped profile_id={profile.id}: {error}")
                continue
            except (FaceRegistrationError, TypeError, ValueError) as error:
                print(
                    "Face login skipped invalid signature for "
                    f"profile_id={profile.id}: {error}"
                )
                continue

            score = self.cosine_similarity(probe_embedding, registered_embedding)

            if score > best_score:
                best_score = score
                best_profile = profile

        if best_profile is None:
            reason = (
                "Stored face signature model mismatch."
                if model_mismatch_count > 0
                else "Face not recognized."
            )
            self._log_face_login_decision(
                best_profile_id=None,
                best_score=best_score,
                accepted=False,
                reason=reason,
            )
            raise FaceLoginError(reason)

        if best_score < FACE_LOGIN_THRESHOLD:
            self._log_face_login_decision(
                best_profile_id=best_profile.id,
                best_score=best_score,
                accepted=False,
                reason="Face not recognized.",
            )
            raise FaceLoginError("Face not recognized.")

        if best_profile.is_blacklisted:
            self._log_face_login_decision(
                best_profile_id=best_profile.id,
                best_score=best_score,
                accepted=False,
                reason="Blacklisted profile.",
            )
            raise FaceLoginError("Face login is not allowed for this profile.")

        self._log_face_login_decision(
            best_profile_id=best_profile.id,
            best_score=best_score,
            accepted=True,
        )
        return best_profile

    def cosine_similarity(self, a: list[float], b: list[float]) -> float:
        if not a or not b or len(a) != len(b):
            return 0.0

        vector_a = np.asarray(a, dtype=np.float32)
        vector_b = np.asarray(b, dtype=np.float32)
        denominator = np.linalg.norm(vector_a) * np.linalg.norm(vector_b)

        if denominator == 0:
            return 0.0

        return float(np.dot(vector_a, vector_b) / denominator)

    def load_registered_profiles(
        self,
        db: Session,
        premise_id: int,
    ) -> list[Profile]:
        if premise_id is None:
            return []

        return (
            db.query(Profile)
            .filter(Profile.premise_id == premise_id)
            .filter(Profile.face_signature.isnot(None))
            .all()
        )

    def recognize_face(
        self,
        image: np.ndarray,
        premise_id: int,
        db: Session,
    ) -> FaceRecognitionResult:
        try:
            probe_embedding = self.generate_embedding(image)
        except FaceRegistrationError as error:
            self._log_recognition_decision(
                best_profile_id=None,
                best_score=0.0,
                matched=False,
                reason=str(error),
            )
            return FaceRecognitionResult.unknown()

        best_profile = None
        best_score = 0.0

        for profile in self.load_registered_profiles(db=db, premise_id=premise_id):
            try:
                registered_embedding = self.deserialize_embedding(
                    profile.face_signature,
                )
            except (FaceRegistrationError, TypeError, ValueError) as error:
                print(
                    "Skipping invalid face signature for profile "
                    f"{profile.id}: {error}"
                )
                continue

            score = self.cosine_similarity(probe_embedding, registered_embedding)

            if score > best_score:
                best_score = score
                best_profile = profile

        if best_profile is None:
            self._log_recognition_decision(
                best_profile_id=None,
                best_score=best_score,
                matched=False,
                reason="no registered face matched",
            )
            return FaceRecognitionResult.unknown(confidence=best_score)

        if best_score >= FACE_MATCH_THRESHOLD:
            self._log_recognition_decision(
                best_profile_id=best_profile.id,
                best_score=best_score,
                matched=True,
            )
            return FaceRecognitionResult.matched_profile(
                profile=best_profile,
                confidence=best_score,
            )

        self._log_recognition_decision(
            best_profile_id=best_profile.id,
            best_score=best_score,
            matched=False,
            reason="below threshold",
        )
        return FaceRecognitionResult.unknown(confidence=best_score)

    def _log_recognition_decision(
        self,
        best_profile_id: int | None,
        best_score: float,
        matched: bool,
        reason: str | None = None,
    ) -> None:
        classification = "known_person" if matched else "unknown_person"
        message = (
            "Face recognition decision: "
            f"best_profile_id={best_profile_id}, "
            f"best_similarity={best_score:.3f}, "
            f"threshold={FACE_MATCH_THRESHOLD:.3f}, "
            f"classification={classification}"
        )

        if reason:
            message = f"{message}, reason={reason}"

        print(message)

    def _log_face_login_decision(
        self,
        best_profile_id: int | None,
        best_score: float,
        accepted: bool,
        reason: str | None = None,
    ) -> None:
        message = (
            "Face login decision: "
            f"best_profile_id={best_profile_id}, "
            f"best_similarity={best_score:.3f}, "
            f"threshold={FACE_LOGIN_THRESHOLD:.3f}, "
            f"accepted={accepted}"
        )

        if reason:
            message = f"{message}, reason={reason}"

        print(message)

    @classmethod
    def _get_face_app(cls) -> FaceAnalysis:
        if cls._face_app is None:
            MODEL_ROOT.mkdir(parents=True, exist_ok=True)
            app = FaceAnalysis(name="buffalo_s", root=str(MODEL_ROOT))
            app.prepare(ctx_id=-1, det_size=(320, 320))
            cls._face_app = app

        return cls._face_app
