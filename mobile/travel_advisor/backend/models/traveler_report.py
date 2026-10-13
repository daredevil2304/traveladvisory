from datetime import datetime

from sqlalchemy import (
    DateTime,
    Float,
    ForeignKey,
    Integer,
    String,
    Text,
)
from sqlalchemy.orm import Mapped, mapped_column

from database import Base


class TravelerReport(Base):
    __tablename__ = "traveler_reports"

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

    trip_id: Mapped[int | None] = mapped_column(
        ForeignKey("trips.id"),
        nullable=True,
        index=True,
    )

    # GPS location at the time of the report.
    latitude: Mapped[float] = mapped_column(
        Float,
        nullable=False,
    )

    longitude: Mapped[float] = mapped_column(
        Float,
        nullable=False,
    )

    # Route region identified by the backend.
    # Example: R1, R4, R7.
    route_region: Mapped[str | None] = mapped_column(
        String(10),
        nullable=True,
        index=True,
    )

    # Exact natural-language statement submitted
    # by the traveler.
    raw_message: Mapped[str] = mapped_column(
        Text,
        nullable=False,
    )

    # Standardized observations extracted from the
    # traveler's natural-language message.
    rain: Mapped[str | None] = mapped_column(
        String(50),
        nullable=True,
    )

    visibility: Mapped[str | None] = mapped_column(
        String(50),
        nullable=True,
    )

    fog: Mapped[str | None] = mapped_column(
        String(50),
        nullable=True,
    )

    unusual_conditions: Mapped[str | None] = mapped_column(
        String(100),
        nullable=True,
    )

    traffic: Mapped[str | None] = mapped_column(
        String(50),
        nullable=True,
    )

    # Stores additional structured information returned
    # by the LLM/observation extraction layer.
    normalized_data: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
    )

    # Extraction confidence can be populated once the
    # LLM extraction service is connected.
    extraction_confidence: Mapped[float | None] = mapped_column(
        Float,
        nullable=True,
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime,
        default=datetime.utcnow,
        nullable=False,
        index=True,
    )