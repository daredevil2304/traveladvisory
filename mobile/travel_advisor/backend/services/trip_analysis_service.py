from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from typing import Any

from sqlalchemy.orm import Session

from models.trip import Trip
from services.google_maps_traffic_service import google_maps_traffic_service
from services.route_segment_service import (
    ROUTE_POINT_COORDINATES,
    get_route_summary,
    get_segment_coordinates,
    resolve_route_segments,
)
from services.segment_intelligence_service import (
    SegmentIntelligenceResult,
    segment_intelligence_service,
)

SEGMENT_NAME_MAP: dict[str, str] = {
    "R1": "Mumbai to Panvel",
    "R2": "Panvel to Khalapur",
    "R3": "Khalapur to Khopoli",
    "R4": "Khopoli to Khandala (Bhor Ghat)",
    "R5": "Khandala to Lonavala",
    "R6": "Lonavala to Kamshet",
    "R7": "Kamshet to Pune",
}


@dataclass(frozen=True)
class TripAnalysisResult:
    """
    Complete intelligence analysis for one trip.

    The result preserves every route segment independently and
    provides a trip-level summary.

    Missing ML models or other unavailable intelligence sources
    are preserved as unavailable rather than being fabricated.
    """

    trip_id: int
    user_id: int
    role: str

    source: str
    destination: str
    travel_datetime: datetime

    route_summary: dict[str, Any]

    segment_results: list[dict[str, Any]]

    evaluated_segments: list[str]
    problematic_segments: list[dict[str, Any]]

    overall_safety_score: float | None
    overall_confidence: float

    available_intelligence_sources: list[str]
    missing_intelligence_sources: list[str]

    reasons: list[str]

    status: str

    def to_dict(self) -> dict[str, Any]:
        return {
            "trip_id": self.trip_id,
            "user_id": self.user_id,
            "role": self.role,
            "source": self.source,
            "destination": self.destination,
            "travel_datetime": self.travel_datetime.isoformat(),
            "route_summary": self.route_summary,
            "evaluated_segments": self.evaluated_segments,
            "segment_results": self.segment_results,
            "problematic_segments": self.problematic_segments,
            "overall_safety_score": self.overall_safety_score,
            "overall_confidence": self.overall_confidence,
            "available_intelligence_sources": (
                self.available_intelligence_sources
            ),
            "missing_intelligence_sources": (
                self.missing_intelligence_sources
            ),
            "reasons": self.reasons,
            "status": self.status,
        }


class TripAnalysisService:
    """
    Orchestrates the complete intelligence pipeline for a trip.

    Pipeline:

        Trip
          ↓
        Route resolution
          ↓
        R1 → R2 → ... → R7
          ↓
        Segment-specific coordinates
          ↓
        Segment Intelligence Service
          ↓
        Segment Safety Scores
          ↓
        Trip-level aggregation
          ↓
        Final analysis object

    Every route segment is evaluated independently.

    The service does not fabricate ML predictions when regional
    models are unavailable.
    """

    def analyze_trip(
        self,
        db: Session,
        trip_id: int,
    ) -> TripAnalysisResult:
        """
        Analyze one stored trip.

        Every route segment between source and destination is
        evaluated independently.
        """

        # =========================================================
        # 1. LOAD TRIP
        # =========================================================

        trip = (
            db.query(Trip)
            .filter(Trip.id == trip_id)
            .first()
        )

        if trip is None:
            raise ValueError(
                f"Trip with id {trip_id} was not found."
            )

        # =========================================================
        # 2. ROUTE SUMMARY
        # =========================================================

        route_summary = get_route_summary(
            source=trip.source_name,
            destination=trip.destination_name,
        )

        route_segments = resolve_route_segments(
            source=trip.source_name,
            destination=trip.destination_name,
        )

        # =========================================================
        # 3. HANDLE SAME-POINT JOURNEY
        # =========================================================

        if not route_segments:
            return self._build_empty_route_result(
                trip=trip,
                route_summary=route_summary,
            )

        # =========================================================
        # 4. EVALUATE EVERY ROUTE SEGMENT
        # =========================================================

        segment_results: list[dict[str, Any]] = []

        is_traveler = (trip.role or "").lower() == "traveler"
        seg_endpoints = {
            "R1": ("Mumbai", "Panvel"),
            "R2": ("Panvel", "Khalapur"),
            "R3": ("Khalapur", "Khopoli"),
            "R4": ("Khopoli", "Khandala"),
            "R5": ("Khandala", "Lonavala"),
            "R6": ("Lonavala", "Kamshet"),
            "R7": ("Kamshet", "Pune"),
        }

        for region in route_segments:
            result = self._evaluate_segment(
                db=db,
                trip=trip,
                region=region,
            )

            res_dict = result.to_dict()

            # LIVE TRAFFIC ONLY FOR TRAVELER SECTION (NOT PLANNER)
            if is_traveler:
                start_name, end_name = seg_endpoints.get(region.upper(), ("Panvel", "Pune"))
                start_c = ROUTE_POINT_COORDINATES.get(start_name, (18.98878, 73.11013))
                end_c = ROUTE_POINT_COORDINATES.get(end_name, (18.52050, 73.85650))
                traffic = google_maps_traffic_service.get_segment_traffic(
                    start_coords=start_c,
                    end_coords=end_c,
                    start_name=start_name,
                    end_name=end_name,
                )
                res_dict["live_traffic"] = traffic

                # If notable congestion or delay, surface as a traveler evidence reason
                if traffic.get("delay_minutes", 0) >= 3 or traffic.get("congestion_level") in ("moderate", "heavy", "standstill"):
                    traffic_msg = f"Traffic flow: {traffic.get('status_label')} (~{traffic.get('delay_minutes')}m delay, cruising speed {traffic.get('speed_advice')})"
                    safety_score_res = res_dict.get("safety_score_result")
                    if isinstance(safety_score_res, dict):
                        current_reasons = safety_score_res.get("reasons")
                        if isinstance(current_reasons, list):
                            current_reasons.append(traffic_msg)
            else:
                # Strictly excluded for Planner trips (relies on weather forecasts only)
                res_dict["live_traffic"] = None

            segment_results.append(
                res_dict
            )

        # =========================================================
        # 5. TRIP-LEVEL AGGREGATION
        # =========================================================

        overall_safety_score = (
            self._calculate_overall_safety_score(
                segment_results
            )
        )

        overall_confidence = (
            self._calculate_overall_confidence(
                segment_results
            )
        )

        problematic_segments = (
            self._identify_problematic_segments(
                segment_results
            )
        )

        available_sources = (
            self._collect_available_sources(
                segment_results
            )
        )

        missing_sources = (
            self._collect_missing_sources(
                segment_results
            )
        )

        reasons = self._collect_reasons(
            segment_results
        )

        status = self._determine_status(
            segment_results=segment_results,
            overall_safety_score=overall_safety_score,
        )

        return TripAnalysisResult(
            trip_id=trip.id,
            user_id=trip.user_id,
            role=trip.role,
            source=trip.source_name,
            destination=trip.destination_name,
            travel_datetime=trip.travel_datetime,
            route_summary=route_summary,
            segment_results=segment_results,
            evaluated_segments=route_segments,
            problematic_segments=problematic_segments,
            overall_safety_score=overall_safety_score,
            overall_confidence=overall_confidence,
            available_intelligence_sources=available_sources,
            missing_intelligence_sources=missing_sources,
            reasons=reasons,
            status=status,
        )

    # =============================================================
    # SEGMENT EVALUATION
    # =============================================================

    @staticmethod
    def _evaluate_segment(
        db: Session,
        trip: Trip,
        region: str,
    ) -> SegmentIntelligenceResult:
        """
        Evaluate one route segment using that segment's
        representative coordinates.

        The coordinates come from route_segment_service rather
        than using the trip's source coordinates for every region.
        """

        latitude, longitude = get_segment_coordinates(
            region
        )

        return segment_intelligence_service.evaluate_segment(
            db=db,
            region=region,
            latitude=latitude,
            longitude=longitude,
            travel_datetime=trip.travel_datetime,
        )

    # =============================================================
    # OVERALL SAFETY SCORE
    # =============================================================

    @staticmethod
    def _calculate_overall_safety_score(
        segment_results: list[dict[str, Any]],
    ) -> float | None:
        """
        Calculate the trip-level Safety Score.

        The current aggregation uses the weakest evaluated segment
        rather than a simple average.

        This ensures that a substantially affected segment is not
        hidden by stronger conditions elsewhere on the journey.

        Only segments with an actual Safety Score are considered.
        """

        scores: list[float] = []

        for segment in segment_results:
            safety_result = segment.get(
                "safety_score_result"
            )

            if not isinstance(
                safety_result,
                dict,
            ):
                continue

            score = safety_result.get(
                "safety_score"
            )

            if not isinstance(
                score,
                (int, float),
            ):
                continue

            scores.append(
                float(score)
            )

        if not scores:
            return None

        return round(
            max(
                0.0,
                min(
                    100.0,
                    min(scores),
                ),
            ),
            2,
        )

    # =============================================================
    # OVERALL CONFIDENCE
    # =============================================================

    @staticmethod
    def _calculate_overall_confidence(
        segment_results: list[dict[str, Any]],
    ) -> float:
        """
        Calculate trip-level evidence confidence.

        The weakest evaluated segment determines the trip-level
        confidence so that a poorly observed segment is not hidden
        by better-observed segments.
        """

        confidences: list[float] = []

        for segment in segment_results:
            safety_result = segment.get(
                "safety_score_result"
            )

            if not isinstance(
                safety_result,
                dict,
            ):
                continue

            confidence = safety_result.get(
                "confidence"
            )

            if not isinstance(
                confidence,
                (int, float),
            ):
                continue

            confidences.append(
                float(confidence)
            )

        if not confidences:
            return 0.0

        return round(
            max(
                0.0,
                min(
                    100.0,
                    min(confidences),
                ),
            ),
            2,
        )

    # =============================================================
    # PROBLEMATIC SEGMENTS
    # =============================================================

    @staticmethod
    def _identify_problematic_segments(
        segment_results: list[dict[str, Any]],
    ) -> list[dict[str, Any]]:
        """
        Identify segments that deserve attention.

        Current operational rule:

        - Safety Score below 60, OR
        - explicit segment-level reasons are present.

        This is an application-level attention rule and can later
        be calibrated using project evaluation data.
        """

        problematic: list[dict[str, Any]] = []

        for segment in segment_results:
            region = segment.get(
                "region"
            )

            segment_details = segment.get(
                "segment_details"
            )

            safety_result = segment.get(
                "safety_score_result"
            )

            if not isinstance(
                safety_result,
                dict,
            ):
                continue

            score = safety_result.get(
                "safety_score"
            )

            reasons = safety_result.get(
                "reasons"
            )

            if not isinstance(
                reasons,
                list,
            ):
                reasons = []

            has_hazard = any(
                any(
                    neg in r.lower()
                    for neg in [
                        "rain",
                        "fog",
                        "mist",
                        "reduced visibility",
                        "wind",
                        "waterlog",
                        "slippery",
                        "damage",
                        "closure",
                        "accident",
                        "incident",
                        "debris",
                        "heavy traffic",
                        "standstill",
                        "landslide",
                    ]
                )
                for r in reasons
            )

            score_is_low = (
                isinstance(
                    score,
                    (int, float),
                )
                and float(score) < 80.0
            )

            if not score_is_low and not has_hazard:
                continue

            reg_display = SEGMENT_NAME_MAP.get(str(region).upper(), region)
            problematic.append(
                {
                    "region": reg_display,
                    "region_code": region,
                    "segment_details": segment_details,
                    "safety_score": score,
                    "confidence": safety_result.get(
                        "confidence"
                    ),
                    "reasons": reasons,
                }
            )

        return problematic

    # =============================================================
    # AVAILABLE SOURCES
    # =============================================================

    @staticmethod
    def _collect_available_sources(
        segment_results: list[dict[str, Any]],
    ) -> list[str]:
        """
        Collect intelligence sources that were available in at
        least one evaluated segment.
        """

        source_names: set[str] = set()

        for segment in segment_results:
            safety_result = segment.get(
                "safety_score_result"
            )

            if not isinstance(
                safety_result,
                dict,
            ):
                continue

            sources = safety_result.get(
                "available_sources"
            )

            if not isinstance(
                sources,
                list,
            ):
                continue

            for source in sources:
                if isinstance(
                    source,
                    str,
                ):
                    source_names.add(
                        source
                    )

        return sorted(
            source_names
        )

    # =============================================================
    # MISSING SOURCES
    # =============================================================

    @staticmethod
    def _collect_missing_sources(
        segment_results: list[dict[str, Any]],
    ) -> list[str]:
        """
        Collect intelligence sources that are missing from at
        least one evaluated segment.
        """

        source_names: set[str] = set()

        for segment in segment_results:
            safety_result = segment.get(
                "safety_score_result"
            )

            if not isinstance(
                safety_result,
                dict,
            ):
                continue

            sources = safety_result.get(
                "missing_sources"
            )

            if not isinstance(
                sources,
                list,
            ):
                continue

            for source in sources:
                if isinstance(
                    source,
                    str,
                ):
                    source_names.add(
                        source
                    )

        return sorted(
            source_names
        )

    # =============================================================
    # REASONS
    # =============================================================

    @staticmethod
    def _collect_reasons(
        segment_results: list[dict[str, Any]],
    ) -> list[str]:
        """
        Collect unique reasons while preserving the region in
        which each reason occurred.
        """

        reasons: list[str] = []
        seen: set[str] = set()

        for segment in segment_results:
            region = segment.get(
                "region"
            )

            safety_result = segment.get(
                "safety_score_result"
            )

            if not isinstance(
                safety_result,
                dict,
            ):
                continue

            segment_reasons = safety_result.get(
                "reasons"
            )

            if not isinstance(
                segment_reasons,
                list,
            ):
                continue

            for reason in segment_reasons:
                if not isinstance(
                    reason,
                    str,
                ):
                    continue

                reg_display = SEGMENT_NAME_MAP.get(str(region).upper(), region)
                contextual_reason = (
                    f"{reg_display}: {reason}"
                )

                if contextual_reason in seen:
                    continue

                seen.add(
                    contextual_reason
                )

                reasons.append(
                    contextual_reason
                )

        return reasons

    # =============================================================
    # STATUS
    # =============================================================

    @staticmethod
    def _determine_status(
        *,
        segment_results: list[dict[str, Any]],
        overall_safety_score: float | None,
    ) -> str:
        """
        Determine the operational status of the trip analysis.

        This status is not itself a safety classification.
        """

        if not segment_results:
            return "no_route_segments"

        if overall_safety_score is None:
            return "analysis_unavailable"

        if any(
            segment.get("status")
            == "safety_score_available"
            for segment in segment_results
        ):
            return "analysis_available"

        return "partial_analysis"

    # =============================================================
    # SAME-POINT JOURNEY
    # =============================================================

    @staticmethod
    def _build_empty_route_result(
        *,
        trip: Trip,
        route_summary: dict[str, Any],
    ) -> TripAnalysisResult:
        """
        Handle source == destination.

        No R1-R7 route segment exists in this situation.
        """

        return TripAnalysisResult(
            trip_id=trip.id,
            user_id=trip.user_id,
            role=trip.role,
            source=trip.source_name,
            destination=trip.destination_name,
            travel_datetime=trip.travel_datetime,
            route_summary=route_summary,
            segment_results=[],
            evaluated_segments=[],
            problematic_segments=[],
            overall_safety_score=None,
            overall_confidence=0.0,
            available_intelligence_sources=[],
            missing_intelligence_sources=[
                "ml",
                "weather",
                "traveler",
            ],
            reasons=[
                "Source and destination are the same route point."
            ],
            status="no_route_segments",
        )


# ================================================================
# SHARED SERVICE INSTANCE
# ================================================================

trip_analysis_service = TripAnalysisService()