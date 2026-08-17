from sqlalchemy import BigInteger, CheckConstraint, Column, DateTime, ForeignKey, Integer, Numeric, String
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func

from app.db.database import Base


class Sensor(Base):
    __tablename__ = "sensors"
    __table_args__ = (
        CheckConstraint("sampling_interval IS NULL OR sampling_interval > 0", name="ck_sensors_sampling_interval"),
    )

    device_id = Column(Integer, ForeignKey("devices.id", ondelete="CASCADE"), primary_key=True)
    sensor_type = Column(String(100), nullable=False)
    sampling_interval = Column(Integer)

    device = relationship("Device", back_populates="sensor")
    capabilities = relationship("SensorCapability", back_populates="sensor", cascade="all, delete-orphan")
    readings = relationship("SensorReading", back_populates="sensor", cascade="all, delete-orphan")


class MeasurementType(Base):
    __tablename__ = "measurement_types"

    id = Column(Integer, primary_key=True)
    name = Column(String(100), nullable=False, unique=True)
    default_unit = Column(String(30), nullable=False)

    capabilities = relationship("SensorCapability", back_populates="measurement_type")
    reading_values = relationship("ReadingValue", back_populates="measurement_type")


class SensorCapability(Base):
    __tablename__ = "sensor_capabilities"
    __table_args__ = (
        CheckConstraint(
            "minimum_value IS NULL OR maximum_value IS NULL OR minimum_value <= maximum_value",
            name="ck_sensor_capability_range",
        ),
    )

    sensor_id = Column(Integer, ForeignKey("sensors.device_id", ondelete="CASCADE"), primary_key=True)
    measurement_type_id = Column(Integer, ForeignKey("measurement_types.id", ondelete="RESTRICT"), primary_key=True)
    minimum_value = Column(Numeric(12, 3))
    maximum_value = Column(Numeric(12, 3))
    warning_threshold = Column(Numeric(12, 3))
    critical_threshold = Column(Numeric(12, 3))

    sensor = relationship("Sensor", back_populates="capabilities")
    measurement_type = relationship("MeasurementType", back_populates="capabilities")


class SensorReading(Base):
    __tablename__ = "sensor_readings"

    id = Column(BigInteger, primary_key=True, index=True)
    sensor_id = Column(Integer, ForeignKey("sensors.device_id", ondelete="CASCADE"), nullable=False, index=True)
    recorded_at = Column(DateTime(timezone=True), nullable=False, server_default=func.now())

    sensor = relationship("Sensor", back_populates="readings")
    values = relationship("ReadingValue", back_populates="reading", cascade="all, delete-orphan")
    events = relationship("AIEvent", back_populates="sensor_reading")

    def value_for(self, measurement_name: str):
        for reading_value in self.values:
            measurement_type = reading_value.measurement_type
            if measurement_type is not None and measurement_type.name == measurement_name:
                return reading_value.value
        return None


class ReadingValue(Base):
    __tablename__ = "reading_values"

    reading_id = Column(BigInteger, ForeignKey("sensor_readings.id", ondelete="CASCADE"), primary_key=True)
    measurement_type_id = Column(Integer, ForeignKey("measurement_types.id", ondelete="RESTRICT"), primary_key=True)
    value = Column(Numeric(12, 3), nullable=False)

    reading = relationship("SensorReading", back_populates="values")
    measurement_type = relationship("MeasurementType", back_populates="reading_values")
