from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from database import Base
from services.timezone_service import get_ist_now


class CommuteHabit(Base):
    """
    Stores learned or customized commute habits for a traveler.
    """

    __tablename__ = "commute_habits"

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

    source_name: Mapped[str] = mapped_column(
        String(150),
        nullable=False,
        default="Panvel",
    )

    destination_name: Mapped[str] = mapped_column(
        String(150),
        nullable=False,
        default="Pune",
    )

    departure_time: Mapped[str] = mapped_column(
        String(20),
        nullable=False,
        default="08:00",
    )

    observed_check_time: Mapped[str] = mapped_column(
        String(20),
        nullable=False,
        default="07:50",
    )

    alert_time: Mapped[str] = mapped_column(
        String(20),
        nullable=False,
        default="07:45",
    )

    is_enabled: Mapped[bool] = mapped_column(
        Boolean,
        default=True,
        nullable=False,
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime,
        default=get_ist_now,
        nullable=False,
    )

    updated_at: Mapped[datetime] = mapped_column(
        DateTime,
        default=get_ist_now,
        onupdate=get_ist_now,
        nullable=False,
    )


class CommuteCheckLog(Base):
    """
    Logs timestamped journey checks to detect recurring commute habits.
    """

    __tablename__ = "commute_check_logs"

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

    source_name: Mapped[str] = mapped_column(
        String(150),
        nullable=False,
    )

    destination_name: Mapped[str] = mapped_column(
        String(150),
        nullable=False,
    )

    departure_time: Mapped[str | None] = mapped_column(
        String(20),
        nullable=True,
    )

    check_time: Mapped[str] = mapped_column(
        String(20),
        nullable=False,
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime,
        default=get_ist_now,
        nullable=False,
        index=True,
    )
