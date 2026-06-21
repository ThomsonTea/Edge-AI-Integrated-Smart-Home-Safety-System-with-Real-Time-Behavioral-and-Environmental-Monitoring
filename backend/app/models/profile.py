from sqlalchemy import Column, Integer, String, Boolean, Text, ForeignKey, DateTime
from app.db.database import Base
from sqlalchemy.orm import relationship

class Profile(Base):
    __tablename__ = "profiles"
    id = Column(Integer, primary_key=True, index=True)
    premise_id = Column(Integer, ForeignKey("premises.id", ondelete="SET NULL"))
    username = Column(String(255), nullable=False)
    phone_number = Column(String(20), unique=True, index=True, nullable=True)
    group_type = Column(String(100))
    hash_password = Column(Text)
    face_signature = Column(Text)
    profile_image_path = Column(Text)
    last_seen = Column(DateTime(timezone=True))
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
