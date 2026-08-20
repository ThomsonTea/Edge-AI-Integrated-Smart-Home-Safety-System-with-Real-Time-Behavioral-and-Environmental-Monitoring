from typing import Literal

from pydantic import BaseModel, Field, field_validator


class CameraCreate(BaseModel):
    name: str = Field(min_length=1, max_length=255)
    location: str | None = Field(default=None, max_length=255)
    stream_url: str = Field(min_length=1)
    username: str | None = Field(default=None, max_length=255)
    password: str | None = None
    stream_protocol: Literal["rtsp", "http", "https"] = "rtsp"
    confidence_threshold: float = Field(default=0.7, ge=0, le=1)
    snapshot_enabled: bool = True
    detection_enabled: bool = True

    @field_validator("name", "stream_url")
    @classmethod
    def required_text(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("must not be blank")
        return value


class CameraUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=255)
    location: str | None = Field(default=None, max_length=255)
    stream_url: str | None = Field(default=None, min_length=1)
    username: str | None = Field(default=None, max_length=255)
    password: str | None = None
    stream_protocol: Literal["rtsp", "http", "https"] | None = None
    confidence_threshold: float | None = Field(default=None, ge=0, le=1)
    snapshot_enabled: bool | None = None
    detection_enabled: bool | None = None
    enabled: bool | None = None


class CameraConnectionTest(BaseModel):
    stream_url: str = Field(min_length=1)
    username: str | None = None
    password: str | None = None


class CameraStreamResolve(BaseModel):
    service_url: str = Field(min_length=1)
    username: str = Field(min_length=1)
    password: str = Field(min_length=1)
