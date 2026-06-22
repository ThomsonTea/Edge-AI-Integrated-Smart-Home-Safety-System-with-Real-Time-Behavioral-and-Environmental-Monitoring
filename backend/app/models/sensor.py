from sqlalchemy import BigInteger, Column, DateTime, ForeignKey, Integer, Numeric, String
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func

from app.db.database import Base


class SensorReading(Base):
    __tablename__ = "sensor_readings"

    id = Column(BigInteger, primary_key=True, index=True)
    premise_id = Column(Integer, ForeignKey("premises.id", ondelete="CASCADE"), nullable=False)
    temperature = Column(Numeric(5, 2))
    humidity = Column(Numeric(5, 2))
    gas = Column(Integer)
    sensor_status = Column(String(20), nullable=False, default="connected")
    recorded_at = Column(DateTime(timezone=True), nullable=False, server_default=func.now())

    premise = relationship("Premise", back_populates="sensor_readings")
