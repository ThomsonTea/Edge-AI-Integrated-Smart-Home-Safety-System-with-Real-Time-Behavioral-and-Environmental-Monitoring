from sqlalchemy import Column, Integer, String, Boolean, Text, ForeignKey, DateTime, Numeric, CheckConstraint
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from database import Base

class SystemConfig(Base):
    __tablename__ = "system_configs"
    config_key = Column(String(255), primary_key=True)
    config_value = Column(Text, nullable=False)
    description = Column(Text)
    last_updated = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

class Premise(Base):
    __tablename__ = "premises"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(255), nullable=False)
    type = Column(String(100))
    address = Column(Text)

    # Relationships
    devices = relationship("Device", back_populates="premise")
    profiles = relationship("Profile", back_populates="premise")
    events = relationship("AIEvent", back_populates="premise")

class Device(Base):
    __tablename__ = "devices"
    id = Column(Integer, primary_key=True, index=True)
    premise_id = Column(Integer, ForeignKey("premises.id", ondelete="CASCADE"))
    device_name = Column(String(255), nullable=False)
    device_type = Column(String(100))
    status = Column(Boolean, default=True)
    stream_url = Column(Text)
    last_heartbeat = Column(DateTime(timezone=True))

    premise = relationship("Premise", back_populates="devices")

class Profile(Base):
    __tablename__ = "profiles"
    id = Column(Integer, primary_key=True, index=True)
    premise_id = Column(Integer, ForeignKey("premises.id", ondelete="SET NULL"))
    full_name = Column(String(255), nullable=False)
    group_type = Column(String(100))
    hash_password = Column(Text)
    face_signature = Column(Text)
    last_seen = Column(DateTime(timezone=True))
    is_blacklisted = Column(Boolean, default=False)
    email = Column(String(255), unique=True, nullable=False)

    premise = relationship("Premise", back_populates="profiles")
    notifications = relationship("NotificationRouting", back_populates="profile")
    events = relationship("AIEvent", back_populates="profile")

class NotificationRouting(Base):
    __tablename__ = "notification_routing"
    id = Column(Integer, primary_key=True, index=True)
    profile_id = Column(Integer, ForeignKey("profiles.id", ondelete="CASCADE"))
    alert_type = Column(String(100))
    whatsapp_number = Column(String(20))
    twilio_opt_in_status = Column(Boolean, default=False)

    profile = relationship("Profile", back_populates="notifications")

class AIEvent(Base):
    __tablename__ = "ai_events"
    id = Column(Integer, primary_key=True, index=True)
    premise_id = Column(Integer, ForeignKey("premises.id", ondelete="CASCADE"))
    profile_id = Column(Integer, ForeignKey("profiles.id", ondelete="SET NULL"))
    event_type = Column(String(100))
    confidence_score = Column(Numeric(5, 2))
    image_path = Column(Text)
    is_acknowledged = Column(Boolean, default=False)
    timestamp = Column(DateTime(timezone=True), server_default=func.now())

    __table_args__ = (
        CheckConstraint('confidence_score >= 0 AND confidence_score <= 100', name='check_confidence'),
    )

    premise = relationship("Premise", back_populates="events")
    profile = relationship("Profile", back_populates="events")