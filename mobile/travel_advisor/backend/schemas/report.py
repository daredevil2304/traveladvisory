from datetime import datetime

from pydantic import BaseModel, Field


# ================================================================
# SAVE REPORT REQUEST
# ================================================================


class SaveReportRequest(BaseModel):
    user_id: int = Field(
        ge=1,
    )

    trip_id: int = Field(
        ge=1,
    )

    title: str = Field(
        min_length=1,
        max_length=200,
    )


# ================================================================
# SAVED REPORT SUMMARY
# ================================================================


class SavedReportSummary(BaseModel):
    id: int

    trip_id: int

    title: str

    source: str

    destination: str

    role: str

    travel_datetime: datetime

    safety_score: float | None = None

    confidence: float | None = None

    created_at: datetime


# ================================================================
# SAVED REPORT DETAIL
# ================================================================


class SavedReportDetail(BaseModel):
    id: int

    user_id: int

    trip_id: int

    title: str

    source: str

    destination: str

    role: str

    travel_datetime: datetime

    safety_score: float | None = None

    confidence: float | None = None

    advisory: str | None = None

    analysis_data: dict

    created_at: datetime