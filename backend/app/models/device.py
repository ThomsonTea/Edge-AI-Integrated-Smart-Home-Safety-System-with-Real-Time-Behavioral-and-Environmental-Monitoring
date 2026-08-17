from sqlalchemy import Boolean, CheckConstraint, Column, DateTime, ForeignKey, Integer, Numeric, String, Text, UniqueConstraint
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func

from app.db.database import Base


class Device(Base):
    __tablename__ = "devices"
    __table_args__ = (
        UniqueConstraint("premise_id", "device_name", name="uq_devices_premise_name"),
        CheckConstraint("device_type IN ('camera', 'sensor')", name="ck_devices_type"),
        CheckConstraint(
            "connection_status IN ('online', 'offline', 'connecting', 'error')",
            name="ck_devices_connection_status",
        ),
    )

    id = Column(Integer, primary_key=True, index=True)
    premise_id = Column(Integer, ForeignKey("premises.id", ondelete="CASCADE"), nullable=False, index=True)
    device_name = Column(String(255), nullable=False)
    device_type = Column(String(50), nullable=False, index=True)
    location = Column(String(255))
    enabled = Column(Boolean, nullable=False, default=True)
    connection_status = Column(String(20), nullable=False, default="offline")
    last_heartbeat = Column(DateTime(timezone=True))
    created_at = Column(DateTime(timezone=True), nullable=False, server_default=func.now())
    updated_at = Column(DateTime(timezone=True), nullable=False, server_default=func.now(), onupdate=func.now())

    premise = relationship("Premise", back_populates="devices")
    camera = relationship("Camera", back_populates="device", uselist=False, cascade="all, delete-orphan")
    sensor = relationship("Sensor", back_populates="device", uselist=False, cascade="all, delete-orphan")
    events = relationship("AIEvent", back_populates="source_device")


class Camera(Base):
    __tablename__ = "cameras"
    __table_args__ = (
        CheckConstraint("stream_protocol IN ('rtsp', 'http', 'https')", name="ck_cameras_stream_protocol"),
        CheckConstraint("confidence_threshold BETWEEN 0 AND 1", name="ck_cameras_confidence_threshold"),
    )

    device_id = Column(Integer, ForeignKey("devices.id", ondelete="CASCADE"), primary_key=True)
    stream_url = Column(Text, nullable=False)
    username = Column(String(255))
    encrypted_password = Column(Text)
    stream_protocol = Column(String(20), nullable=False, default="rtsp")
    confidence_threshold = Column(Numeric(4, 3), nullable=False, default=0.700)
    snapshot_enabled = Column(Boolean, nullable=False, default=True)
    detection_enabled = Column(Boolean, nullable=False, default=True)

    device = relationship("Device", back_populates="camera")
    ai_features = relationship("CameraAIFeature", back_populates="camera", cascade="all, delete-orphan")


class AIDetectionType(Base):
    __tablename__ = "ai_detection_types"

    id = Column(Integer, primary_key=True)
    name = Column(String(100), nullable=False, unique=True)
    description = Column(Text)

    camera_features = relationship("CameraAIFeature", back_populates="detection_type")


class CameraAIFeature(Base):
    __tablename__ = "camera_ai_features"
    __table_args__ = (
        CheckConstraint("confidence_threshold BETWEEN 0 AND 1", name="ck_camera_ai_features_confidence"),
    )

    camera_id = Column(Integer, ForeignKey("cameras.device_id", ondelete="CASCADE"), primary_key=True)
    ai_detection_type_id = Column(Integer, ForeignKey("ai_detection_types.id", ondelete="RESTRICT"), primary_key=True)
    enabled = Column(Boolean, nullable=False, default=True)
    confidence_threshold = Column(Numeric(4, 3), nullable=False, default=0.700)

    camera = relationship("Camera", back_populates="ai_features")
    detection_type = relationship("AIDetectionType", back_populates="camera_features")
