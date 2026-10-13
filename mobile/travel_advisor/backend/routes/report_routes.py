from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from database import get_db
from models.travel_report import TravelReport
from schemas.report import (
    SaveReportRequest,
    SavedReportDetail,
    SavedReportSummary,
)
from services.report_service import report_service


router = APIRouter(
    prefix="/reports",
    tags=["Reports"],
)


# ================================================================
# SAVE REPORT
# ================================================================


@router.post(
    "",
    response_model=SavedReportDetail,
)
def save_report(
    request: SaveReportRequest,
    db: Session = Depends(get_db),
):
    """
    Save a completed trip analysis as a persistent report.
    """

    # ------------------------------------------------------------
    # Verify that the trip exists and belongs to the user
    # ------------------------------------------------------------

    from models.trip import Trip

    trip = (
        db.query(Trip)
        .filter(
            Trip.id == request.trip_id,
            Trip.user_id == request.user_id,
        )
        .first()
    )

    if trip is None:
        raise HTTPException(
            status_code=404,
            detail="Trip not found or does not belong to this user.",
        )

    # ------------------------------------------------------------
    # Prevent saving an empty analysis
    # ------------------------------------------------------------

    analysis_data = getattr(
        trip,
        "analysis_data",
        None,
    )

    if not analysis_data:
        raise HTTPException(
            status_code=400,
            detail=(
                "No completed analysis is available for this trip. "
                "Analyze the trip before saving the report."
            ),
        )

    try:
        report = report_service.save_report(
            db=db,
            user_id=request.user_id,
            trip_id=request.trip_id,
            title=request.title,
            analysis_data=analysis_data,
        )

    except ValueError as exc:
        raise HTTPException(
            status_code=404,
            detail=str(exc),
        ) from exc

    return _to_detail_response(report)


# ================================================================
# GET ALL REPORTS FOR USER
# ================================================================


@router.get(
    "",
    response_model=list[SavedReportSummary],
)
def get_reports(
    user_id: int,
    db: Session = Depends(get_db),
):
    """
    Return all saved reports belonging to a user.
    """

    reports = report_service.get_user_reports(
        db=db,
        user_id=user_id,
    )

    return [
        _to_summary_response(report)
        for report in reports
    ]


# ================================================================
# GET SINGLE REPORT
# ================================================================


@router.get(
    "/{report_id}",
    response_model=SavedReportDetail,
)
def get_report(
    report_id: int,
    user_id: int,
    db: Session = Depends(get_db),
):
    """
    Return one saved report belonging to a user.
    """

    report = report_service.get_report(
        db=db,
        user_id=user_id,
        report_id=report_id,
    )

    if report is None:
        raise HTTPException(
            status_code=404,
            detail="Report not found.",
        )

    return _to_detail_response(report)


# ================================================================
# DELETE REPORT
# ================================================================


@router.delete(
    "/{report_id}",
)
def delete_report(
    report_id: int,
    user_id: int,
    db: Session = Depends(get_db),
):
    """
    Delete one saved report belonging to a user.
    """

    deleted = report_service.delete_report(
        db=db,
        user_id=user_id,
        report_id=report_id,
    )

    if not deleted:
        raise HTTPException(
            status_code=404,
            detail="Report not found.",
        )

    return {
        "message": "Report deleted successfully.",
        "report_id": report_id,
    }


# ================================================================
# RESPONSE HELPERS
# ================================================================


def _to_summary_response(
    report: TravelReport,
) -> SavedReportSummary:

    return SavedReportSummary(
        id=report.id,
        trip_id=report.trip_id,
        title=report.title,
        source=report.source_name,
        destination=report.destination_name,
        role=report.role,
        travel_datetime=report.travel_datetime,
        safety_score=report.safety_score,
        confidence=report.confidence,
        created_at=report.created_at,
    )


def _to_detail_response(
    report: TravelReport,
) -> SavedReportDetail:

    return SavedReportDetail(
        id=report.id,
        user_id=report.user_id,
        trip_id=report.trip_id,
        title=report.title,
        source=report.source_name,
        destination=report.destination_name,
        role=report.role,
        travel_datetime=report.travel_datetime,
        safety_score=report.safety_score,
        confidence=report.confidence,
        advisory=report.advisory,
        analysis_data=report.analysis_data,
        created_at=report.created_at,
    )