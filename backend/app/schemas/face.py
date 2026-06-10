from pydantic import BaseModel


class FaceRegistrationResponse(BaseModel):
    message: str
    profile_id: int
    has_face_signature: bool
