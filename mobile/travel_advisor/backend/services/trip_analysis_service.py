from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
import concurrent.futures
from typing import Any

from sqlalchemy.orm import Session

from models.trip import Trip
from services.corridor_physics_service import corridor_physics_service
from services.departure_optimizer_service import departure_optimizer_service
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

    departure_optimization: dict[str, Any] | None = None
    elevation_profile: list[dict[str, Any]] | None = None
    emergency_directory: dict[str, Any] | None = None

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
            "departure_optimization": self.departure_optimization,
            "elevation_profile": self.elevation_profile,
            "emergency_directory": self.emergency_directory,
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
        # 4. EVALUATE EVERY ROUTE SEGMENT (CONCURRENT EXECUTION)
        # =========================================================

        is_traveler = (trip.role or "").lower() in ("traveler", "traveller")
        is_planner = not is_traveler

        seg_endpoints = {
            "R1": ("Mumbai", "Panvel"),
            "R2": ("Panvel", "Khalapur"),
            "R3": ("Khalapur", "Khopoli"),
            "R4": ("Khopoli", "Khandala"),
            "R5": ("Khandala", "Lonavala"),
            "R6": ("Lonavala", "Kamshet"),
            "R7": ("Kamshet", "Pune"),
        }

        # Calculate planned departure time of day (IST)
        from services.timezone_service import to_ist
        travel_dt = trip.travel_datetime or datetime.now(timezone.utc)
        ist_travel_dt = to_ist(travel_dt)
        ist_hour = ist_travel_dt.hour
        is_night_travel = (ist_hour >= 19 or ist_hour < 6)

        # Batch fetch all recent traveler reports in a single query across segments
        reports_by_region: dict[str, list[Any]] = {}
        if is_traveler:
            from services.traveler_report_retrieval_service import (
                traveler_report_retrieval_service,
            )
            reports_by_region = traveler_report_retrieval_service.get_reports_for_regions(
                db=db,
                regions=route_segments,
                reference_datetime=travel_dt,
                lookback_hours=1,
            )

        # Parallelize independent segment evaluation across threads
        results_by_region: dict[str, dict[str, Any]] = {}
        max_threads = max(1, min(len(route_segments), 7))
        with concurrent.futures.ThreadPoolExecutor(max_workers=max_threads) as executor:
            future_to_region = {
                executor.submit(
                    self._evaluate_single_segment_worker,
                    region=region,
                    is_traveler=is_traveler,
                    is_planner=is_planner,
                    is_night_travel=is_night_travel,
                    ist_hour=ist_hour,
                    travel_dt=travel_dt,
                    seg_endpoints=seg_endpoints,
                    prefetched_reports=reports_by_region.get(region.upper(), []),
                ): region
                for region in route_segments
            }
            for future in concurrent.futures.as_completed(future_to_region):
                reg = future_to_region[future]
                results_by_region[reg.upper()] = future.result()

        # Preserve exact route sequence order [R1, R2, ..., R7]
        segment_results = [results_by_region[r.upper()] for r in route_segments]

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

        # Proactive departure optimization window (+/- 1 hr for planner, +30m/+60m for live traveler)
        is_live_traveler = (trip.role or "").lower() in ("traveler", "traveller")
        departure_optimization = departure_optimizer_service.optimize_departure_window(
            base_datetime=trip.travel_datetime or datetime.now(timezone.utc),
            route_segments=route_segments,
            current_safety_score=overall_safety_score,
            is_live_traveler=is_live_traveler,
            live_traffic_by_region={
                r.upper(): results_by_region[r.upper()].get("live_traffic")
                for r in route_segments
                if r.upper() in results_by_region
            },
        )

        # Corridor elevation cross-section profile & 24x7 emergency rescue directory
        elevation_profile = corridor_physics_service.get_elevation_profile()
        emergency_directory = corridor_physics_service.get_emergency_directory()

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
            departure_optimization=departure_optimization,
            elevation_profile=elevation_profile,
            emergency_directory=emergency_directory,
        )

    # =============================================================
    # SEGMENT EVALUATION WORKER (PARALLEL EXECUTION)
    # =============================================================

    @staticmethod
    def _evaluate_single_segment_worker(
        region: str,
        is_traveler: bool,
        is_planner: bool,
        is_night_travel: bool,
        ist_hour: int,
        travel_dt: datetime,
        seg_endpoints: dict[str, tuple[str, str]],
        prefetched_reports: list[Any] | None,
    ) -> dict[str, Any]:
        reg_code = region.upper()
        segment_traffic = None
        seg_terrain_score = None
        seg_terrain_reasons: list[str] = []

        if is_traveler:
            start_name, end_name = seg_endpoints.get(reg_code, ("Panvel", "Pune"))
            start_c = ROUTE_POINT_COORDINATES.get(start_name, (18.98878, 73.11013))
            end_c = ROUTE_POINT_COORDINATES.get(end_name, (18.52050, 73.85650))
            segment_traffic = google_maps_traffic_service.get_segment_traffic(
                start_coords=start_c,
                end_coords=end_c,
                start_name=start_name,
                end_name=end_name,
            )
        else:
            if reg_code in ("R4", "R5"):  # Bhor Ghat mountain pass & crest
                t_score = 90.0 if reg_code == "R4" else 94.0
                if is_night_travel:
                    t_score -= 15.0  # Drops to 75 / 79 for night mountain curves & low lighting
                    seg_terrain_reasons.append(
                        f"Night mountain driving ({ist_hour:02d}:00 IST): Low lighting, darkness and sharp hairpin turns."
                    )
            elif reg_code in ("R3", "R6"):  # Foothills & descending plateau
                t_score = 97.0
                if is_night_travel:
                    t_score -= 8.0  # Drops to 89
                    seg_terrain_reasons.append(
                        f"Night highway approach ({ist_hour:02d}:00 IST): Darkness on unlit stretches approaching Ghat."
                    )
            else:  # R1, R2, R7 plain expressway
                t_score = 100.0
                if is_night_travel:
                    t_score -= 6.0  # Drops to 94
                    seg_terrain_reasons.append(
                        f"Night travel window ({ist_hour:02d}:00 IST): Darkness on unlit stretches and headlight glare."
                    )

            seg_terrain_score = max(0.0, min(100.0, t_score))

        latitude, longitude = get_segment_coordinates(region)

        result = segment_intelligence_service.evaluate_segment(
            db=None,
            region=region,
            latitude=latitude,
            longitude=longitude,
            travel_datetime=travel_dt,
            live_traffic=segment_traffic,
            is_planner=is_planner,
            terrain_score=seg_terrain_score,
            terrain_reasons=seg_terrain_reasons,
            prefetched_reports=prefetched_reports or [],
        )

        res_dict = result.to_dict()
        safety_score_res = res_dict.get("safety_score_result")
        if not isinstance(safety_score_res, dict):
            safety_score_res = {}
            res_dict["safety_score_result"] = safety_score_res

        score_val = safety_score_res.get("safety_score")
        res_dict["safety_score"] = score_val
        res_dict["reasons"] = safety_score_res.get("reasons", [])
        res_dict["risk_factors"] = safety_score_res.get("risk_factors", [])
        if isinstance(segment_traffic, dict):
            dim_scores = safety_score_res.get("dimension_scores", {})
            if "user_report_traffic" in dim_scores:
                segment_traffic["user_report_traffic_score"] = dim_scores["user_report_traffic"]
                segment_traffic["traffic_weighting"] = "80% Google Maps / 20% User Report"
        res_dict["live_traffic"] = segment_traffic

        w_res = res_dict.get("weather_result")
        safe_speed = corridor_physics_service.compute_safe_speed(
            region=region,
            weather_data=w_res if isinstance(w_res, dict) else None,
            safety_score=score_val,
            is_night=is_night_travel,
        )
        res_dict["safe_speed_advisory"] = safe_speed

        reg_elevation_map = {
            "R1": 14,
            "R2": 48,
            "R3": 72,
            "R4": 550,
            "R5": 624,
            "R6": 585,
            "R7": 560,
        }
        res_dict["elevation_m"] = reg_elevation_map.get(reg_code, 500)

        return res_dict

    # =============================================================
    # SEGMENT EVALUATION
    # =============================================================

    @staticmethod
    def _evaluate_segment(
        db: Session,
        trip: Trip,
        region: str,
        live_traffic: dict[str, Any] | None = None,
        is_planner: bool = False,
        terrain_score: float | None = None,
        terrain_reasons: list[str] | None = None,
    ) -> SegmentIntelligenceResult:
        """
        Evaluate one route segment using that segment's
        representative coordinates and intelligence inputs.
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
            live_traffic=live_traffic,
            is_planner=is_planner,
            terrain_score=terrain_score,
            terrain_reasons=terrain_reasons,
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
        Identify segments that deserve special driver caution ("Regions to Watch Out For").

        Operational rule:
        - Segments scoring below 85.0 (cautionary / degraded safety), OR
        - Segments with active critical hazards (accidents, heavy rain, dense fog, bottleneck delays >= 5m).

        Safe segments (score >= 85.0 with normal fluid conditions) are strictly excluded.
        The reasons list for flagged segments contains ONLY the specific active risk factors.
        """
        problematic: list[dict[str, Any]] = []

        for segment in segment_results:
            region = segment.get("region")
            segment_details = segment.get("segment_details")
            safety_result = segment.get("safety_score_result")

            if not isinstance(safety_result, dict):
                continue

            score = safety_result.get("safety_score")
            if score is None or not isinstance(score, (int, float)):
                continue

            score_val = float(score)

            # Retrieve genuine risk factors identified during evaluation
            risk_factors = safety_result.get("risk_factors") or []
            if not isinstance(risk_factors, list):
                risk_factors = []

            # Filter out any non-hazard / diagnostic / affirmative phrases
            clean_risks = [
                r for r in risk_factors
                if isinstance(r, str) and not any(
                    ign in r.lower()
                    for ign in [
                        "xgboost",
                        "historical ml",
                        "clear route",
                        "optimal fluid",
                        "advance planning mode",
                        "no delays reported",
                    ]
                )
            ]

            # Only flag as caution area if score < 80.0 OR active critical hazards exist
            # If route is safe without problems (score >= 80.0 and no active hazards), keep it safe!
            if score_val >= 80.0 and not clean_risks:
                continue

            # If score is below 80 but clean_risks is empty, give a clean simple reason
            if not clean_risks:
                clean_risks = [f"Moderate caution advised on this stretch ({round(score_val)}/100)."]

            reg_display = SEGMENT_NAME_MAP.get(str(region).upper(), region)
            problematic.append(
                {
                    "region": reg_display,
                    "region_code": region,
                    "segment_details": segment_details,
                    "safety_score": score_val,
                    "confidence": safety_result.get("confidence"),
                    "reasons": clean_risks,
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