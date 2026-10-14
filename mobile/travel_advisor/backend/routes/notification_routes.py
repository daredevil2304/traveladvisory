from __future__ import annotations

from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from database import get_db
from services.commute_notification_service import commute_notification_service

router = APIRouter(
    prefix="/notifications",
    tags=["Notifications & Commute Habits"],
)


class CommuteHabitUpdateRequest(BaseModel):
    user_id: int = Field(..., example=1)
    source: str = Field(..., example="Panvel")
    destination: str = Field(..., example="Pune")
    departure_time: str = Field(..., example="08:00")
    alert_time: str = Field(..., example="07:45")
    is_enabled: bool = Field(True, example=True)


class CommuteLogRequest(BaseModel):
    user_id: int = Field(..., example=1)
    source: str = Field(..., example="Panvel")
    destination: str = Field(..., example="Pune")
    departure_time: str | None = Field(None, example="08:00")
    check_time: str | None = Field(None, example="07:50")


@router.get("/commute-habit")
def get_commute_habit(
    user_id: int = Query(..., description="ID of the user"),
    db: Session = Depends(get_db),
) -> dict[str, Any]:
    """
    Retrieve learned or configured commute habit and scheduled alert time.
    """
    try:
        habit = commute_notification_service.get_commute_habit(
            db=db,
            user_id=user_id,
        )
        return {
            "status": "success",
            "habit": habit,
        }
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Unable to load commute habit: {str(e)}",
        )


@router.post("/commute-habit")
def save_commute_habit(
    request: CommuteHabitUpdateRequest,
    db: Session = Depends(get_db),
) -> dict[str, Any]:
    """
    Update or customize daily commute habit and alert notification schedule.
    """
    try:
        updated = commute_notification_service.save_commute_habit(
            db=db,
            user_id=request.user_id,
            source=request.source,
            destination=request.destination,
            departure_time=request.departure_time,
            alert_time=request.alert_time,
            is_enabled=request.is_enabled,
        )
        return {
            "status": "success",
            "message": "Commute habit updated successfully",
            "habit": updated,
        }
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Unable to save commute habit: {str(e)}",
        )


@router.get("/commute-alert")
def get_commute_alert(
    user_id: int = Query(1, description="ID of the user"),
    source: str = Query("Panvel", description="Journey origin"),
    destination: str = Query("Pune", description="Journey destination"),
    db: Session = Depends(get_db),
) -> dict[str, Any]:
    """
    Generates real-time proactive notification payload evaluating the prediction model,
    weather forecasts, and human community reports within the past 6 hours.
    """
    try:
        alert_payload = commute_notification_service.generate_commute_alert(
            db=db,
            user_id=user_id,
            source=source,
            destination=destination,
        )
        return {
            "status": "success",
            "alert": alert_payload,
        }
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Unable to generate commute alert: {str(e)}",
        )


@router.post("/log-commute-check")
def log_commute_check(
    request: CommuteLogRequest,
    db: Session = Depends(get_db),
) -> dict[str, Any]:
    """
    Log an instant journey check to learn the traveler's recurring habits automatically.
    """
    try:
        log = commute_notification_service.log_commute_check(
            db=db,
            user_id=request.user_id,
            source=request.source,
            destination=request.destination,
            departure_time=request.departure_time,
            check_time=request.check_time,
        )
        return {
            "status": "success",
            "message": "Commute check logged",
            "log_id": log.id,
            "check_time": log.check_time,
        }
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Unable to log commute check: {str(e)}",
        )
