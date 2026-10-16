from __future__ import annotations

import json

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from database import get_db
from models.trip import Trip
from models.user import User
from schemas.trip import (
    TravelerObservationRequest,
    TripRequest,
    TripRequestResponse,
)
from services.route_segment_service import (
    ROUTE_POINT_COORDINATES,
    normalize_location,
    resolve_route_segments,
)
from services.traveler_report_service import (
    traveler_report_service,
)
from services.trip_analysis_service import (
    trip_analysis_service,
)


router = APIRouter(
    prefix="/trip",
    tags=["Trip"],
)


# ================================================================
# CREATE TRIP REQUEST
# ================================================================

@router.post(
    "/request",
    response_model=TripRequestResponse,
)
def create_trip_request(
    request: TripRequest,
    db: Session = Depends(get_db),
):
    """
    Create a traveler/planner trip request.

    Traveler:
        - current date/time is used automatically
        - traveler report is required

    Planner:
        - future travel date/time is required
        - traveler report is not accepted
    """

    # ============================================================
    # 1. VERIFY USER
    # ============================================================

    user = (
        db.query(User)
        .filter(
            User.id == request.user_id
        )
        .first()
    )

    if user is None:
        user = (
            db.query(User)
            .filter(User.is_active == True)
            .order_by(User.id.asc())
            .first()
        )

    if user is None:
        user = User(
            full_name="Corridor Traveler",
            email="traveler@mumbaipune.internal",
            mobile="9999999999",
            password_hash="system_guest_account",
            is_active=True,
            is_verified=True,
        )
        db.add(user)
        db.commit()
        db.refresh(user)

    if not user.is_active:
        user.is_active = True
        db.commit()
        db.refresh(user)

    # ============================================================
    # 2. DETERMINE TRAVEL DATETIME
    # ============================================================

    if request.role == "traveler":
        from services.timezone_service import get_ist_now

        travel_datetime = get_ist_now()

    else:
        from datetime import datetime

        travel_datetime = datetime.combine(
            request.travel_date,
            request.travel_time,
        )

    # ============================================================
    # 3. RESOLVE ROUTE SEGMENTS
    # ============================================================

    try:
        route_segments = resolve_route_segments(
            source=request.source,
            destination=request.destination,
        )

    except ValueError as exc:
        raise HTTPException(
            status_code=400,
            detail=str(exc),
        ) from exc

    # ============================================================
    # 4. CREATE TRIP
    # ============================================================

    trip = Trip(
        user_id=user.id,
        role=request.role,
        source_latitude=request.latitude,
        source_longitude=request.longitude,
        source_name=request.source,
        destination_name=request.destination,
        travel_datetime=travel_datetime,
    )

    db.add(trip)
    db.flush()

    # ============================================================
    # 5. CREATE TRAVELER REPORT
    # ============================================================

    report_id = None
    normalized_report = None
    extraction_confidence = None

    if (
        request.role == "traveler"
        and request.traveler_report is not None
    ):
        report = request.traveler_report

        # --------------------------------------------------------
        # Reconstruct a readable raw message from the structured
        # traveler-report fields.
        # --------------------------------------------------------

        report_parts: list[str] = []

        if report.rain:
            report_parts.append(
                f"Rain: {report.rain}"
            )

        if report.visibility:
            report_parts.append(
                f"Visibility: {report.visibility}"
            )

        if report.fog:
            report_parts.append(
                f"Fog: {report.fog}"
            )

        if report.unusual_conditions:
            report_parts.append(
                "Unusual conditions: "
                f"{report.unusual_conditions}"
            )

        if report.traffic:
            report_parts.append(
                f"Traffic: {report.traffic}"
            )

        raw_message = "; ".join(
            report_parts
        )

        initial_region = (
            route_segments[0]
            if route_segments
            else None
        )

        # --------------------------------------------------------
        # CREATE REPORT THROUGH TRAVELER REPORT SERVICE
        # Only if the traveler actually provided observations
        # --------------------------------------------------------

        if raw_message.strip():
            report, observation = (
                traveler_report_service.create_report_from_message(
                    db=db,
                    user_id=user.id,
                    trip_id=trip.id,
                    latitude=request.latitude,
                    longitude=request.longitude,
                    raw_message=raw_message,
                    route_region=initial_region,
                )
            )

            # --------------------------------------------------------
            # HANDLE CLARIFICATION
            # --------------------------------------------------------

            if observation.needs_clarification:
                pass

        # --------------------------------------------------------
        # STORE REPORT INFORMATION
        # --------------------------------------------------------

        if report is not None:
            report_id = report.id

            normalized_report = (
                report.normalized_data
            )

            extraction_confidence = (
                report.extraction_confidence
            )

            # ----------------------------------------------------
            # IMPORTANT:
            #
            # normalized_data may come from the database as a
            # JSON string instead of a Python dictionary.
            #
            # TripRequestResponse expects a dictionary.
            # Convert the JSON string back into a dictionary.
            # ----------------------------------------------------

            if isinstance(
                normalized_report,
                str,
            ):
                try:
                    normalized_report = json.loads(
                        normalized_report
                    )

                except json.JSONDecodeError:
                    normalized_report = {}

    # ============================================================
    # 6. COMMIT TRIP + REPORT
    # ============================================================

    db.commit()
    db.refresh(trip)

    # ============================================================
    # 7. RESPONSE
    # ============================================================

    return TripRequestResponse(
        message="Trip request created successfully.",
        status="trip_created",
        user_id=trip.user_id,
        role=trip.role,
        source=trip.source_name,
        destination=trip.destination_name,
        latitude=trip.source_latitude,
        longitude=trip.source_longitude,
        travel_date=(
            travel_datetime.date()
            if request.role == "planner"
            else None
        ),
        travel_time=(
            travel_datetime.time()
            if request.role == "planner"
            else None
        ),
        traveler_report=request.traveler_report,
        trip_id=trip.id,
        report_id=report_id,
        report_normalized_data=normalized_report,
        extraction_confidence=extraction_confidence,
    )


# ================================================================
# ANALYZE TRIP
# ================================================================

@router.post(
    "/{trip_id}/analyze",
)
def analyze_trip(
    trip_id: int,
    db: Session = Depends(get_db),
):
    """
    Run the complete intelligence pipeline for a stored trip.

    Pipeline:

        Trip
          ↓
        Route segments
          ↓
        Segment-specific coordinates
          ↓
        Regional ML
          ↓
        OpenWeather
          ↓
        Traveler reports
          ↓
        Dimension-aware fusion
          ↓
        Segment Safety Scores
          ↓
        Trip-level analysis
    """

    # ============================================================
    # 1. VERIFY TRIP EXISTS
    # ============================================================

    trip = (
        db.query(Trip)
        .filter(
            Trip.id == trip_id
        )
        .first()
    )

    if trip is None:
        raise HTTPException(
            status_code=404,
            detail=(
                f"Trip with id {trip_id} "
                "was not found."
            ),
        )

    # ============================================================
    # 2. RUN ANALYSIS
    # ============================================================

    try:
        analysis = (
            trip_analysis_service.analyze_trip(
                db=db,
                trip_id=trip_id,
            )
        )

    except ValueError as exc:
        raise HTTPException(
            status_code=400,
            detail=str(exc),
        ) from exc

    except Exception as exc:
        db.rollback()

        raise HTTPException(
            status_code=500,
            detail={
                "message": "Trip analysis failed.",
                "error": str(exc),
            },
        ) from exc

    # ============================================================
    # 3. STORE COMPLETE ANALYSIS
    # ============================================================

    analysis_data = analysis.to_dict()

    trip.analysis_data = analysis_data

    db.commit()
    db.refresh(trip)

    # ============================================================
    # 4. RETURN COMPLETE ANALYSIS
    # ============================================================

    return analysis_data


# ============================================================
# 5. CHATBOT ALIAS
# ============================================================

@router.post(
    "/{trip_id}/chatbot",
)
def trip_chatbot_alias(
    trip_id: int,
    request: dict,
    db: Session = Depends(get_db),
):
    from services.chatbot_service import chatbot_service
    from services.groq_provider import GroqError

    message = request.get("message", "")

    try:
        result = chatbot_service.answer(
            db=db,
            trip_id=trip_id,
            message=message,
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=404,
            detail=str(exc),
        ) from exc
    except GroqError as exc:
        raise HTTPException(
            status_code=503,
            detail="The chatbot provider could not generate a response.",
        ) from exc
    except Exception as exc:
        raise HTTPException(
            status_code=500,
            detail="Chatbot request failed.",
        ) from exc

    return {
        "trip_id": trip_id,
        "answer": result.answer,
        "provider": result.provider,
        "model": result.model,
    }


# ============================================================
# 6. SUBMIT TRIP OBSERVATION / USER INPUT
# ============================================================

@router.post(
    "/{trip_id}/observation",
)
def submit_trip_observation(
    trip_id: int,
    request: TravelerObservationRequest,
    db: Session = Depends(get_db),
):
    trip = (
        db.query(Trip)
        .filter(Trip.id == trip_id)
        .first()
    )

    if trip is None:
        raise HTTPException(
            status_code=404,
            detail=f"Trip with id {trip_id} was not found.",
        )

    user_id = request.user_id if request.user_id is not None else trip.user_id
    lat = request.latitude if request.latitude is not None else trip.source_latitude
    lon = request.longitude if request.longitude is not None else trip.source_longitude

    resolved_region = request.route_region
    if not resolved_region:
        try:
            # 1. Map GPS position to closest highway point
            if lat is not None and lon is not None:
                best_point = None
                best_dist = float("inf")
                for pt_name, (pt_lat, pt_lon) in ROUTE_POINT_COORDINATES.items():
                    d = (lat - pt_lat) ** 2 + (lon - pt_lon) ** 2
                    if d < best_dist:
                        best_dist = d
                        best_point = pt_name

                point_to_seg = {
                    "Mumbai": "R1",
                    "Panvel": "R2",
                    "Khalapur": "R3",
                    "Khopoli": "R4",
                    "Khandala": "R5",
                    "Lonavala": "R6",
                    "Kamshet": "R7",
                    "Pune": "R7",
                }
                resolved_region = point_to_seg.get(best_point)

            # 2. Map trip starting point
            if not resolved_region and trip.source:
                src_clean = normalize_location(trip.source)
                src_to_seg = {
                    "Mumbai": "R1",
                    "Panvel": "R2",
                    "Khalapur": "R3",
                    "Khopoli": "R4",
                    "Khandala": "R5",
                    "Lonavala": "R6",
                    "Kamshet": "R7",
                    "Pune": "R7",
                }
                resolved_region = src_to_seg.get(src_clean)

            # 3. Fallback to initial route segment
            if not resolved_region:
                segments = resolve_route_segments(trip.source, trip.destination)
                resolved_region = segments[0] if segments else "R1"
        except Exception:
            resolved_region = "R1"

    parts = []
    if request.rain:
        parts.append(f"Rain: {request.rain}")
    if request.visibility:
        parts.append(f"Visibility: {request.visibility}")
    if request.fog:
        parts.append(f"Fog: {request.fog}")
    if request.unusual_conditions:
        parts.append(f"Conditions: {request.unusual_conditions}")
    if request.traffic:
        parts.append(f"Traffic: {request.traffic}")
    if request.raw_message:
        parts.append(request.raw_message)

    msg = "; ".join(parts) if parts else "Traveler highway live update"

    report = traveler_report_service.create_report(
        db=db,
        user_id=user_id,
        trip_id=trip.id,
        latitude=lat,
        longitude=lon,
        raw_message=msg,
        route_region=resolved_region,
        rain=request.rain,
        visibility=request.visibility,
        fog=request.fog,
        unusual_conditions=request.unusual_conditions,
        traffic=request.traffic,
        extraction_confidence=1.0,
    )

    return {
        "status": "success",
        "trip_id": trip_id,
        "report_id": report.id,
        "route_region": resolved_region,
        "message": "Observation recorded successfully.",
    }


# ================================================================
# CORRIDOR SECTOR TELEMETRY (DYNAMIC WEATHER & TRAFFIC)
# ================================================================

@router.get(
    "/corridor-telemetry",
)
def get_corridor_telemetry():
    """
    Get dynamic expressway sector telemetry across all 8 monitoring points,
    combining live OpenWeather and Google Maps road traffic intelligence.
    """
    try:
        from services.google_maps_traffic_service import google_maps_traffic_service
        return google_maps_traffic_service.get_corridor_telemetry()
    except Exception as exc:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to fetch corridor telemetry: {exc}",
        )