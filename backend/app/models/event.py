from sqlalchemy import Column, Integer, String, Boolean, Text, ForeignKey, DateTime, Numeric, CheckConstraint
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.db.database import Base

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