from __future__ import annotations

from datetime import datetime, timedelta
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from database import get_db
from models.traveler_report import TravelerReport
from services.timezone_service import format_ist_iso, get_ist_now
from services.traveler_report_service import traveler_report_service

router = APIRouter(
    prefix="/community",
    tags=["Community Road Updates"],
)

# ================================================================
# CORRIDOR REGION METADATA
# ================================================================

REGION_METADATA: dict[str, dict[str, Any]] = {
    "R1": {
        "name": "Mumbai to Panvel",
        "description": "Urban expressway corridor",
        "latitude": 19.0176,
        "longitude": 72.9867,
    },
    "R2": {
        "name": "Panvel to Khalapur",
        "description": "Lowland plains section",
        "latitude": 18.9027,
        "longitude": 73.1884,
    },
    "R3": {
        "name": "Khalapur to Khopoli",
        "description": "Toll plaza approach",
        "latitude": 18.8022,
        "longitude": 73.3052,
    },
    "R4": {
        "name": "Khopoli to Khandala (Bhor Ghat)",
        "description": "Steep ghat ascent",
        "latitude": 18.7788,
        "longitude": 73.3634,
    },
    "R5": {
        "name": "Khandala to Lonavala",
        "description": "Hill crest pass",
        "latitude": 18.7623,
        "longitude": 73.3946,
    },
    "R6": {
        "name": "Lonavala to Kamshet",
        "description": "Plateau descent and valley",
        "latitude": 18.7587,
        "longitude": 73.4819,
    },
    "R7": {
        "name": "Kamshet to Pune",
        "description": "Dehu Road and Pune bypass",
        "latitude": 18.6417,
        "longitude": 73.7070,
    },
}

REGION_NAME_TO_CODE: dict[str, str] = {
    "mumbai to panvel": "R1",
    "panvel to khalapur": "R2",
    "khalapur to khopoli": "R3",
    "khopoli to khandala": "R4",
    "khopoli to khandala (bhor ghat)": "R4",
    "khandala to lonavala": "R5",
    "lonavala to kamshet": "R6",
    "kamshet to pune": "R7",
    "mumbai": "R1",
    "sion": "R1",
    "vashi": "R1",
    "panvel": "R2",
    "khalapur": "R3",
    "khopoli": "R4",
    "bhor ghat": "R4",
    "ghat": "R4",
    "khandala": "R5",
    "lonavala": "R6",
    "kamshet": "R7",
    "talegaon": "R7",
    "wakad": "R7",
    "pune": "R7",
}

# ================================================================
# SCHEMAS
# ================================================================

class CommunityReportSubmitRequest(BaseModel):
    user_id: int | None = Field(default=None)
    route_region: str = Field(description="Segment code (R1-R7) or segment name")
    visibility: str | None = Field(default=None)
    rain: str | None = Field(default=None)
    road_condition: str | None = Field(default=None)
    traffic: str | None = Field(default=None)
    raw_message: str | None = Field(default=None)
    latitude: float | None = Field(default=None)
    longitude: float | None = Field(default=None)


def _normalize_region_code(region_input: str) -> str:
    cleaned = region_input.strip()
    upper = cleaned.upper()
    if upper in REGION_METADATA:
        return upper

    lower = cleaned.lower()
    if lower in REGION_NAME_TO_CODE:
        return REGION_NAME_TO_CODE[lower]

    for key, code in REGION_NAME_TO_CODE.items():
        if any([key in lower, lower in key]):
            return code

    return "R1"


def _assess_report_hazards(report: TravelerReport) -> tuple[bool, list[str]]:
    hazards: list[str] = []

    # Visibility assessment
    vis = (report.visibility or "").lower()
    if any(k in vis for k in ["fog", "mist", "near zero", "poor", "low", "< 200m", "500m"]):
        hazards.append(f"Visibility: {report.visibility}")

    # Rainfall assessment
    rain = (report.rain or "").lower()
    if any(k in rain for k in ["heavy", "downpour", "moderate", "torrential"]):
        hazards.append(f"Rainfall: {report.rain}")

    # Road condition assessment
    cond = (report.unusual_conditions or "").lower()
    if any(k in cond for k in ["landslide", "rockfall", "waterlog", "pothole", "slippery", "debris", "accident", "hazard"]):
        hazards.append(f"Road condition: {report.unusual_conditions}")

    # Traffic assessment
    trf = (report.traffic or "").lower()
    if any(k in trf for k in ["standstill", "heavy", "congestion", "jam", "severe"]):
        hazards.append(f"Traffic: {report.traffic}")

    return len(hazards) > 0, hazards


# ================================================================
# GET LIVE COMMUNITY ROAD UPDATES (WITH AUTO-EXPIRY)
# ================================================================

@router.get("/live-reports")
def get_live_community_reports(
    hours: int = Query(default=1, ge=1, le=24, description="Lookback window in hours"),
    db: Session = Depends(get_db),
):
    """
    Returns active human traveler reports within the past N hours (default 1h).
    Expired reports are automatically excluded from the output and risk evaluation.
    Computes active risky corridor segments based exclusively on user inputs.
    """
    now = get_ist_now()
    cutoff_time = now - timedelta(hours=hours)

    reports_query = (
        db.query(TravelerReport)
        .filter(
            TravelerReport.created_at >= cutoff_time,
            TravelerReport.created_at <= now,
        )
        .order_by(TravelerReport.created_at.desc())
        .all()
    )

    serialized_reports = []
    region_hazard_map: dict[str, list[dict[str, Any]]] = {}

    for report in reports_query:
        created_dt = report.created_at or now
        age_seconds = max(0, int((now - created_dt).total_seconds()))
        age_minutes = age_seconds // 60
        remaining_minutes = max(0, (hours * 60) - age_minutes)
        if remaining_minutes <= 0 or age_minutes >= (hours * 60):
            continue

        region_code = (report.route_region or "").strip().upper()
        if region_code not in REGION_METADATA:
            # Fallback to identify by keywords in message
            msg = (report.raw_message or "").lower()
            matched = False
            for code, meta in REGION_METADATA.items():
                if meta["name"].lower() in msg or code.lower() in msg:
                    region_code = code
                    matched = True
                    break
            if not matched:
                region_code = "R5"

        region_info = REGION_METADATA.get(region_code, REGION_METADATA["R5"])
        is_risky, hazards = _assess_report_hazards(report)

        report_dict = {
            "id": report.id,
            "user_id": report.user_id,
            "trip_id": report.trip_id,
            "route_region": region_code,
            "region_name": region_info["name"],
            "latitude": report.latitude,
            "longitude": report.longitude,
            "rain": report.rain,
            "visibility": report.visibility,
            "road_condition": report.unusual_conditions,
            "traffic": report.traffic,
            "raw_message": report.raw_message,
            "created_at": format_ist_iso(created_dt),
            "age_minutes": age_minutes,
            "expires_in_minutes": remaining_minutes,
            "is_risky": is_risky,
            "hazards": hazards,
        }

        serialized_reports.append(report_dict)

        if is_risky:
            if region_code not in region_hazard_map:
                region_hazard_map[region_code] = []
            region_hazard_map[region_code].append(report_dict)

    # Compute risky segments
    risky_regions = []
    for reg_code, r_list in region_hazard_map.items():
        reg_info = REGION_METADATA[reg_code]
        all_hazards: list[str] = []
        for r in r_list:
            for h in r["hazards"]:
                if h not in all_hazards:
                    all_hazards.append(h)

        # Determine severity level
        is_high = any(
            any(crit in h.lower() for crit in ["near zero", "dense fog", "landslide", "waterlog", "standstill", "heavy downpour"])
            for h in all_hazards
        )

        level = "High Risk" if is_high else "Caution"
        summary_text = (
            f"Travelers report {', '.join(all_hazards)} along {reg_info['name']}."
        )

        risky_regions.append({
            "region_code": reg_code,
            "segment_name": reg_info["name"],
            "risk_level": level,
            "issues": all_hazards,
            "summary": summary_text,
            "report_count": len(r_list),
            "latest_report_time": r_list[0]["created_at"],
        })

    # High risk segments sorted first
    risky_regions.sort(
        key=lambda x: (0 if x["risk_level"] == "High Risk" else 1, x["region_code"])
    )

    return {
        "status": "success",
        "evaluated_at": format_ist_iso(now),
        "lookback_hours": hours,
        "total_reports": len(serialized_reports),
        "total_risky_regions": len(risky_regions),
        "risky_regions": risky_regions,
        "reports": serialized_reports,
    }


# ================================================================
# SUBMIT COMMUNITY ROAD REPORT
# ================================================================

@router.post("/report")
def submit_community_road_report(
    payload: CommunityReportSubmitRequest,
    db: Session = Depends(get_db),
):
    """
    Submits a standalone community road report visible to all travelers.
    Automatically valid for 1 hour before natural expiration.
    """
    region_code = _normalize_region_code(payload.route_region)
    meta = REGION_METADATA[region_code]

    lat = payload.latitude if payload.latitude is not None else meta["latitude"]
    lon = payload.longitude if payload.longitude is not None else meta["longitude"]
    user_id = payload.user_id if payload.user_id is not None else 1

    parts = []
    if payload.rain:
        parts.append(f"Rain: {payload.rain}")
    if payload.visibility:
        parts.append(f"Visibility: {payload.visibility}")
    if payload.road_condition:
        parts.append(f"Road: {payload.road_condition}")
    if payload.traffic:
        parts.append(f"Traffic: {payload.traffic}")
    if payload.raw_message:
        parts.append(payload.raw_message)

    msg = "; ".join(parts) if parts else f"Live road update for {meta['name']}"

    report = traveler_report_service.create_report(
        db=db,
        user_id=user_id,
        trip_id=None,
        latitude=lat,
        longitude=lon,
        raw_message=msg,
        route_region=region_code,
        rain=payload.rain,
        visibility=payload.visibility,
        fog=None,
        unusual_conditions=payload.road_condition,
        traffic=payload.traffic,
        extraction_confidence=1.0,
    )

    return {
        "status": "success",
        "report_id": report.id,
        "route_region": region_code,
        "segment_name": meta["name"],
        "created_at": format_ist_iso(report.created_at),
        "message": "Community road report recorded successfully.",
    }
