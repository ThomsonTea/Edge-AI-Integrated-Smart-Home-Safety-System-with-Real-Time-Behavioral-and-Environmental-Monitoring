from sqlalchemy import Column, Integer, String, Boolean, Text, ForeignKey, DateTime
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.db.database import Base

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