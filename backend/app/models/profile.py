from sqlalchemy import Boolean, CheckConstraint, Column, DateTime, ForeignKey, Integer, SmallInteger, String, Text, UniqueConstraint
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func

from app.db.database import Base


class Profile(Base):
    __tablename__ = "profiles"
    __table_args__ = (
        CheckConstraint(
            "group_type IN ('owner', 'manager', 'normal_user')",
            name="ck_profiles_group_type",
        ),
    )

    id = Column(Integer, primary_key=True, index=True)
    premise_id = Column(Integer, ForeignKey("premises.id", ondelete="SET NULL"), index=True)
    username = Column(String(255), nullable=False)
    email = Column(String(255), unique=True, nullable=False)
    phone_number = Column(String(20), unique=True, index=True)
    group_type = Column(String(100), nullable=False)
    hash_password = Column(Text, nullable=False)
    face_signature = Column(Text)
    profile_image_path = Column(Text)
    last_seen = Column(DateTime(timezone=True))
    is_blacklisted = Column(Boolean, nullable=False, default=False)

    premise = relationship("Premise", back_populates="profiles")
    events = relationship("AIEvent", back_populates="profile")


class Premise(Base):
    __tablename__ = "premises"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(255), nullable=False)
    type = Column(String(100))
    address = Column(Text)

    devices = relationship("Device", back_populates="premise", cascade="all, delete-orphan")
    profiles = relationship("Profile", back_populates="premise")
    events = relationship("AIEvent", back_populates="premise", cascade="all, delete-orphan")
    settings = relationship("PremiseSetting", back_populates="premise", uselist=False, cascade="all, delete-orphan")
    emergency_contacts = relationship("EmergencyContact", back_populates="premise", cascade="all, delete-orphan")


class PremiseSetting(Base):
    __tablename__ = "premise_settings"
    __table_args__ = (
        CheckConstraint(
            "image_retention_days BETWEEN 1 AND 3650",
            name="ck_premise_settings_retention",
        ),
        CheckConstraint(
            "event_retention_days BETWEEN 1 AND 3650",
            name="ck_premise_settings_event_retention",
        ),
        CheckConstraint(
            "sensor_retention_days BETWEEN 1 AND 3650",
            name="ck_premise_settings_sensor_retention",
        ),
    )

    premise_id = Column(Integer, ForeignKey("premises.id", ondelete="CASCADE"), primary_key=True)
    auto_delete_images = Column(Boolean, nullable=False, default=True)
    image_retention_days = Column(Integer, nullable=False, default=30)
    event_retention_days = Column(Integer, nullable=False, default=90)
    sensor_retention_days = Column(Integer, nullable=False, default=30)
    preserve_unacknowledged = Column(Boolean, nullable=False, default=True)
    preserve_critical = Column(Boolean, nullable=False, default=True)
    created_at = Column(DateTime(timezone=True), nullable=False, server_default=func.now())
    updated_at = Column(DateTime(timezone=True), nullable=False, server_default=func.now(), onupdate=func.now())

    premise = relationship("Premise", back_populates="settings")


class EmergencyContact(Base):
    __tablename__ = "emergency_contacts"
    __table_args__ = (
        UniqueConstraint(
            "premise_id",
            "phone_number",
            name="uq_emergency_contacts_premise_phone",
        ),
        CheckConstraint(
            "priority BETWEEN 1 AND 100",
            name="ck_emergency_contacts_priority",
        ),
    )

    id = Column(Integer, primary_key=True)
    premise_id = Column(Integer, ForeignKey("premises.id", ondelete="CASCADE"), nullable=False, index=True)
    contact_name = Column(String(255), nullable=False)
    phone_number = Column(String(20), nullable=False)
    relationship_label = Column("relationship", String(100))
    priority = Column(SmallInteger, nullable=False, default=1)
    enabled = Column(Boolean, nullable=False, default=True)
    created_at = Column(DateTime(timezone=True), nullable=False, server_default=func.now())
    updated_at = Column(DateTime(timezone=True), nullable=False, server_default=func.now(), onupdate=func.now())

    premise = relationship("Premise", back_populates="emergency_contacts")
