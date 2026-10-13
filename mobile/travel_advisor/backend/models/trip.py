from datetime import datetime

from sqlalchemy import DateTime, Float, ForeignKey, Integer, JSON, String
from sqlalchemy.orm import Mapped, mapped_column

from database import Base


class Trip(Base):
    __tablename__ = "trips"

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

    role: Mapped[str] = mapped_column(
        String(20),
        nullable=False,
        index=True,
    )

    source_latitude: Mapped[float] = mapped_column(
        Float,
        nullable=False,
    )

    source_longitude: Mapped[float] = mapped_column(
        Float,
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

    destination_latitude: Mapped[float | None] = mapped_column(
        Float,
        nullable=True,
    )

    destination_longitude: Mapped[float | None] = mapped_column(
        Float,
        nullable=True,
    )

    travel_datetime: Mapped[datetime] = mapped_column(
        DateTime,
        nullable=False,
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime,
        default=datetime.utcnow,
        nullable=False,
    )

    # ================================================================
    # STORED TRIP ANALYSIS
    # ================================================================

    analysis_data: Mapped[dict | None] = mapped_column(
        JSON,
        nullable=True,
    )