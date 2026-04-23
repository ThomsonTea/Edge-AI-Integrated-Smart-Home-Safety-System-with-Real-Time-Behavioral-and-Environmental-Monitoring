from sqlalchemy import Column, Integer, String, Boolean, Text, ForeignKey, DateTime
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from backend.app.db.database import Base

class NotificationRouting(Base):
    __tablename__ = "notification_routing"
    id = Column(Integer, primary_key=True, index=True)
    profile_id = Column(Integer, ForeignKey("profiles.id", ondelete="CASCADE"))
    alert_type = Column(String(100))
    whatsapp_number = Column(String(20))
    twilio_opt_in_status = Column(Boolean, default=False)

    profile = relationship("Profile", back_populates="notifications")

class SystemConfig(Base):
    __tablename__ = "system_configs"
    config_key = Column(String(255), primary_key=True)
    config_value = Column(Text, nullable=False)
    description = Column(Text)  
    last_updated = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

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