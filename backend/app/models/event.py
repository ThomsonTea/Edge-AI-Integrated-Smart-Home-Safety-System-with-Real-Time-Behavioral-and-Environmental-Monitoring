from sqlalchemy import BigInteger, Boolean, CheckConstraint, Column, DateTime, ForeignKey, Integer, Numeric, String, Text
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func

from app.db.database import Base


class AIEvent(Base):
    __tablename__ = "ai_events"
    __table_args__ = (
        CheckConstraint("severity IN ('low', 'medium', 'high', 'critical')", name="ck_ai_events_severity"),
        CheckConstraint(
            "confidence_score IS NULL OR confidence_score BETWEEN 0 AND 1",
            name="ck_ai_events_confidence",
        ),
    )

    id = Column(BigInteger, primary_key=True, index=True)
    premise_id = Column(Integer, ForeignKey("premises.id", ondelete="CASCADE"), nullable=False, index=True)
    source_device_id = Column(Integer, ForeignKey("devices.id", ondelete="SET NULL"), index=True)
    sensor_reading_id = Column(BigInteger, ForeignKey("sensor_readings.id", ondelete="SET NULL"), index=True)
    profile_id = Column(Integer, ForeignKey("profiles.id", ondelete="SET NULL"))
    event_type = Column(String(100), nullable=False)
    severity = Column(String(20), nullable=False, default="medium")
    confidence_score = Column(Numeric(4, 3))
    image_path = Column(Text)
    is_acknowledged = Column(Boolean, nullable=False, default=False)
    is_pinned = Column(Boolean, nullable=False, default=False)
    timestamp = Column(DateTime(timezone=True), nullable=False, server_default=func.now())

    premise = relationship("Premise", back_populates="events")
    profile = relationship("Profile", back_populates="events")
    source_device = relationship("Device", back_populates="events")
    sensor_reading = relationship("SensorReading", back_populates="events")
