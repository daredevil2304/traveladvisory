from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Integer, JSON, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from database import Base
from services.timezone_service import get_ist_now


class TravelReport(Base):
    __tablename__ = "travel_reports"

    id: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
        index=True,
    )

    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id"),
        nullable=False,
        index=True,
    )

    trip_id: Mapped[int] = mapped_column(
        ForeignKey("trips.id"),
        nullable=False,
        index=True,
    )

    title: Mapped[str] = mapped_column(
        String(200),
        nullable=False,
    )

    source_name: Mapped[str] = mapped_column(
        String(150),
        nullable=False,
    )

    destination_name: Mapped[str] = mapped_column(
        String(150),
        nullable=False,
    )

    role: Mapped[str] = mapped_column(
        String(20),
        nullable=False,
    )

    travel_datetime: Mapped[datetime] = mapped_column(
        DateTime,
        nullable=False,
    )

    safety_score: Mapped[float | None] = mapped_column(
        nullable=True,
    )

    confidence: Mapped[float | None] = mapped_column(
        nullable=True,
    )

    advisory: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
    )

    analysis_data: Mapped[dict] = mapped_column(
        JSON,
        nullable=False,
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime,
        default=get_ist_now,
        nullable=False,
    )