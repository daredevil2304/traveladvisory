from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from typing import Any

from sqlalchemy.orm import Session

from services.data_fusion_service import (
    FusionResult,
    data_fusion_service,
)
from services.prediction_service import (
    PredictionResult,
    prediction_service,
)
from services.route_segment_service import (
    get_segment_details,
)
from services.safety_score_service import (
    SafetyScoreResult,
    safety_score_service,
)
from services.traveler_report_retrieval_service import (
    traveler_report_retrieval_service,
)
from services.weather_normalizer import (
    NormalizedWeather,
    weather_normalizer,
)
from services.weather_service import (
    WeatherData,
    WeatherServiceError,
    weather_service,
)


@dataclass(frozen=True)
class SegmentIntelligenceResult:
    """
    Complete intelligence result for one route segment.

    The result preserves each source independently, stores the
    dimension-aware fusion output, and stores the resulting
    segment-level Safety Score.
    """

    region: str

    segment_details: dict[str, Any] | None

    historical_result: dict[str, Any] | None
    weather_result: dict[str, Any] | None
    report_result: list[dict[str, Any]]

    fusion_result: dict[str, Any]

    safety_score_result: dict[str, Any]

    status: str

    def to_dict(self) -> dict:
        return {
            "region": self.region,
            "segment_details": self.segment_details,
            "historical_result": self.historical_result,
            "weather_result": self.weather_result,
            "report_result": self.report_result,
            "fusion_result": self.fusion_result,
            "safety_score_result": self.safety_score_result,
            "status": self.status,
        }


class SegmentIntelligenceService:
    """
    Orchestrates the intelligence sources for one route segment.

    Sources:

        1. Regional historical ML
        2. OpenWeather
        3. Recent traveler reports

    Pipeline:

        Sources
            ↓
        Dimension normalization
            ↓
        Dimension-aware fusion
            ↓
        Safety Score
            ↓
        Segment intelligence result

    This service calculates the segment-level Safety Score.

    It does NOT calculate the final route-level Safety Score.
    """

    REPORT_LOOKBACK_HOURS = 1

    def evaluate_segment(
        self,
        db: Session | None,
        region: str,
        latitude: float,
        longitude: float,
        travel_datetime: datetime,
        is_planner: bool = False,
        live_traffic: dict[str, Any] | None = None,
        terrain_score: float | None = None,
        terrain_reasons: list[str] | None = None,
        prefetched_reports: list[Any] | None = None,
    ) -> SegmentIntelligenceResult:
        """
        Evaluate one route segment.

        latitude/longitude represents the location used for
        weather retrieval for this segment.
        """

        normalized_region = self._normalize_region(
            region
        )

        # =========================================================
        # 1. Route segment metadata
        # =========================================================

        segment_details = self._get_segment_details(
            normalized_region
        )

        start_city = segment_details.get("start") if isinstance(segment_details, dict) else None

        # =========================================================
        # 2. OpenWeather (Current for Traveler, Forecast for Planner)
        # =========================================================

        (
            weather_result,
            weather_dimensions,
        ) = self._get_weather_result(
            latitude=latitude,
            longitude=longitude,
            target_datetime=travel_datetime,
            city_name=start_city,
            is_planner=is_planner,
        )

        # =========================================================
        # 3. Regional ML Prediction (Cost-Weighted XGBoost)
        # Uses atmospheric readings from weather_result
        # =========================================================

        historical_prediction = (
            self._get_historical_prediction(
                region=normalized_region,
                travel_datetime=travel_datetime,
                weather_data=weather_result,
            )
        )

        historical_result = (
            historical_prediction.to_dict()
        )

        # =========================================================
        # 4. Recent traveler reports (Traveler mode only)
        # =========================================================

        if not is_planner:
            if prefetched_reports is not None:
                reports = prefetched_reports
            elif db is not None:
                reports = (
                    traveler_report_retrieval_service.get_recent_reports(
                        db=db,
                        region=normalized_region,
                        reference_datetime=travel_datetime,
                        lookback_hours=self.REPORT_LOOKBACK_HOURS,
                    )
                )
            else:
                reports = []

            serialized_reports = (
                traveler_report_retrieval_service.serialize_reports(
                    reports
                )
            )

            report_dimensions = (
                self._build_report_dimensions(
                    serialized_reports,
                    weather_dimensions=weather_dimensions,
                    live_traffic=live_traffic,
                )
            )
        else:
            reports = []
            serialized_reports = []
            report_dimensions = None

        # =========================================================
        # 5. Dimension-aware fusion
        # =========================================================

        fusion = data_fusion_service.fuse(
            historical_result=(
                self._extract_prediction_data(
                    historical_prediction
                )
            ),
            weather_result=weather_dimensions,
            report_result=report_dimensions,
        )

        fusion_result = fusion.to_dict()

        # =========================================================
        # 6. Segment Safety Score (Fair multi-source formula)
        # =========================================================

        safety_score = (
            safety_score_service.calculate_segment_score(
                region=normalized_region,
                historical_result=historical_result,
                weather_result=weather_dimensions,
                traveler_result=report_dimensions,
                fusion_result=fusion_result,
                traffic_result=live_traffic,
                is_planner=is_planner,
                terrain_score=terrain_score,
                terrain_reasons=terrain_reasons,
            )
        )

        safety_score_result = (
            safety_score.to_dict()
        )

        # =========================================================
        # 7. Operational status
        # =========================================================

        status = self._determine_status(
            historical_prediction=historical_prediction,
            weather_result=weather_result,
            reports=serialized_reports,
            fusion=fusion,
            safety_score=safety_score,
        )

        # =========================================================
        # 8. Final result
        # =========================================================

        return SegmentIntelligenceResult(
            region=normalized_region,
            segment_details=segment_details,
            historical_result=historical_result,
            weather_result=weather_result,
            report_result=serialized_reports,
            fusion_result=fusion_result,
            safety_score_result=safety_score_result,
            status=status,
        )

    # =============================================================
    # HISTORICAL ML
    # =============================================================

    def _get_historical_prediction(
        self,
        region: str,
        travel_datetime: datetime,
        weather_data: dict[str, Any] | None = None,
    ) -> PredictionResult:
        """
        Get the regional ML prediction.

        Passes atmospheric context (temp, humidity, pressure) and temporal
        factors (month, hour in IST) to the regional XGBoost model.
        """

        return prediction_service.predict(
            region=region,
            travel_datetime=travel_datetime,
            features=weather_data,
        )

    # =============================================================
    # WEATHER
    # =============================================================

    def _get_weather_result(
        self,
        latitude: float,
        longitude: float,
        target_datetime: datetime | None = None,
        city_name: str | None = None,
        is_planner: bool = False,
    ) -> tuple[
        dict[str, Any] | None,
        dict[str, Any] | None,
    ]:
        """
        Retrieve and normalize OpenWeather information.
        When is_planner is True, ALWAYS queries the 5-day forecast.
        When target_datetime is in the future, queries the 5-day forecast.
        Otherwise queries current live weather.
        """
        try:
            is_future = is_planner
            if not is_future and target_datetime is not None:
                from services.timezone_service import get_ist_now_aware, to_ist
                target_ist = to_ist(target_datetime)
                diff_seconds = (target_ist - get_ist_now_aware()).total_seconds()
                # If target is at least 30 minutes in the future, use forecast
                if diff_seconds > 1800:
                    is_future = True

            if is_future:
                weather: WeatherData = (
                    weather_service.get_forecast_weather(
                        latitude=latitude,
                        longitude=longitude,
                        target_time=target_datetime,
                        city_name=city_name,
                    )
                )
            else:
                weather: WeatherData = (
                    weather_service.get_current_weather(
                        latitude=latitude,
                        longitude=longitude,
                        city_name=city_name,
                    )
                )

            normalized: NormalizedWeather = (
                weather_normalizer.normalize(
                    weather
                )
            )

            weather_dict = normalized.to_dict()

            weather_dimensions = (
                self._build_weather_dimensions(
                    normalized
                )
            )

            return (
                weather_dict,
                weather_dimensions,
            )

        except WeatherServiceError as exc:
            return (
                {
                    "status": "weather_unavailable",
                    "error": str(exc),
                },
                None,
            )

        except Exception as exc:
            return (
                {
                    "status": "weather_error",
                    "error": str(exc),
                },
                None,
            )

    @staticmethod
    def _build_weather_dimensions(
        weather: NormalizedWeather,
    ) -> dict[str, Any] | None:
        """
        Convert normalized weather into dimension-level data.
        """

        dimensions: dict[str, Any] = {}

        if weather.rain_condition is not None:
            dimensions["rain"] = (
                weather.rain_condition
            )

        if weather.visibility_condition is not None:
            dimensions["visibility"] = (
                weather.visibility_condition
            )

        if weather.fog_condition is not None:
            dimensions["fog"] = (
                weather.fog_condition
            )

        if weather.weather_condition is not None:
            dimensions["weather_condition"] = (
                weather.weather_condition
            )

        if weather.temperature_c is not None:
            dimensions["temperature_c"] = weather.temperature_c

        if weather.humidity_percent is not None:
            dimensions["humidity_percent"] = weather.humidity_percent

        if weather.pressure_hpa is not None:
            dimensions["pressure_hpa"] = weather.pressure_hpa

        if weather.wind_speed_kmh is not None:
            dimensions["wind_speed_kmh"] = weather.wind_speed_kmh

        if weather.rainfall_mm is not None:
            dimensions["rainfall_mm"] = weather.rainfall_mm

        if weather.visibility_km is not None:
            dimensions["visibility_km"] = weather.visibility_km

        return dimensions or None

    # =============================================================
    # TRAVELER REPORTS
    # =============================================================

    @staticmethod
    def _build_report_dimensions(
        reports: list[dict[str, Any]],
        weather_dimensions: dict[str, Any] | None = None,
        live_traffic: dict[str, Any] | None = None,
    ) -> dict[str, Any] | None:
        """
        Aggregate recent traveler observations by dimension, cross-comparing with
        authoritative APIs (OpenWeather for weather, Google Maps for traffic).

        If multiple users report different conditions at the same time:
        - Weather dimensions (rain, visibility, fog): preference is given to the OpenWeather API live data.
        - Traffic dimensions (traffic, road delays): preference is given to Google Maps telemetry.
        """

        if not reports:
            return None

        dimensions: dict[str, Any] = {}

        fields = (
            "rain",
            "visibility",
            "fog",
            "unusual_conditions",
            "risk",
            "traffic",
        )

        for field in fields:

            values: list[str] = []

            for report in reports:

                value = report.get(
                    field
                )

                if not isinstance(
                    value,
                    str,
                ):
                    continue

                value = value.strip()

                if not value:
                    continue

                if field in {
                    "fog",
                    "unusual_conditions",
                    "risk",
                    "traffic",
                }:
                    if value.casefold() in {"none", "null"}:
                        continue

                values.append(value)

            if not values:
                continue

            # -----------------------------------------------------
            # Count values
            # -----------------------------------------------------

            counts: dict[str, int] = {}

            for value in values:

                key = value.casefold()

                counts[key] = (
                    counts.get(key, 0)
                    + 1
                )

            # If multiple users report conflicting observations (len(counts) > 1),
            # or if 3+ reports have differing conditions, arbitrate in favor of verified APIs:
            if len(counts) > 1:
                if field in ("rain", "visibility", "fog") and weather_dimensions:
                    api_val = weather_dimensions.get(field)
                    if api_val and str(api_val).strip() and str(api_val).casefold() not in {"null", "none"}:
                        dimensions[field] = str(api_val).strip()
                        continue
                elif field in ("traffic", "unusual_conditions") and live_traffic:
                    congestion = str(live_traffic.get("congestion_level", "")).lower()
                    delay = live_traffic.get("delay_minutes", 0)
                    if delay >= 15 or congestion == "heavy":
                        dimensions[field] = "heavy congestion"
                    elif delay >= 5 or congestion == "moderate":
                        dimensions[field] = "moderate delay"
                    else:
                        dimensions[field] = "free flow"
                    continue

            highest_count = max(
                counts.values()
            )

            candidate_keys = {
                key
                for key, count in counts.items()
                if count == highest_count
            }

            # -----------------------------------------------------
            # Tie-break:
            # reports are newest-first.
            # -----------------------------------------------------

            selected_value = None

            for value in values:

                if (
                    value.casefold()
                    in candidate_keys
                ):
                    selected_value = value
                    break

            if selected_value is not None:
                # Sanity check against OpenWeather API for weather:
                if field in ("rain", "visibility", "fog") and weather_dimensions:
                    api_val = weather_dimensions.get(field)
                    if (
                        str(selected_value).casefold() in {"heavy rain", "very heavy rain", "downpour"}
                        and api_val
                        and str(api_val).casefold() in {"no rain", "none", "clear"}
                    ):
                        selected_value = str(api_val)

                dimensions[field] = (
                    selected_value
                )

        return dimensions or None

    # =============================================================
    # ML OUTPUT
    # =============================================================

    @staticmethod
    def _extract_prediction_data(
        prediction: PredictionResult,
    ) -> Any | None:
        """
        Preserve the ML output without assuming its schema.

        The Safety Score service will only interpret explicitly
        recognized safety/risk fields.
        """

        if (
            prediction.status
            != "prediction_available"
        ):
            return None

        return prediction.prediction

    # =============================================================
    # ROUTE METADATA
    # =============================================================

    @staticmethod
    def _get_segment_details(
        region: str,
    ) -> dict[str, Any] | None:
        """
        Retrieve canonical route metadata.
        """

        try:

            details = get_segment_details(
                region
            )

            if hasattr(details, "start") and hasattr(details, "end"):
                return {
                    "region": details.region,
                    "start": details.start,
                    "end": details.end,
                }

            if isinstance(
                details,
                dict,
            ):
                return details

            return {
                "region": region,
                "details": str(details),
            }

        except Exception:
            return None

    # =============================================================
    # STATUS
    # =============================================================

    @staticmethod
    def _determine_status(
        historical_prediction: PredictionResult,
        weather_result: dict[str, Any] | None,
        reports: list[dict[str, Any]],
        fusion: FusionResult,
        safety_score: SafetyScoreResult,
    ) -> str:
        """
        Determine operational status.

        This is an availability/status indicator, not a safety
        classification.
        """

        if (
            safety_score.safety_score is not None
        ):
            return "safety_score_available"

        if fusion.status in {
            "consensus_reached",
            "partial_or_full_consensus",
        }:
            return "consensus_available"

        historical_available = (
            historical_prediction.model_available
        )

        weather_available = (
            weather_result is not None
            and weather_result.get(
                "status"
            )
            not in {
                "weather_unavailable",
                "weather_error",
            }
        )

        reports_available = bool(
            reports
        )

        if (
            historical_available
            or weather_available
            or reports_available
        ):
            return "partial_intelligence_available"

        return "intelligence_unavailable"

    # =============================================================
    # REGION VALIDATION
    # =============================================================

    @staticmethod
    def _normalize_region(
        region: str,
    ) -> str:
        """
        Normalize and validate a route region.
        """

        if not isinstance(
            region,
            str,
        ):
            raise ValueError(
                "region must be a string."
            )

        normalized = (
            region.strip().upper()
        )

        if normalized not in {
            "R1",
            "R2",
            "R3",
            "R4",
            "R5",
            "R6",
            "R7",
        }:
            raise ValueError(
                f"Unsupported route region: "
                f"{normalized}."
            )

        return normalized


# Shared service instance.
segment_intelligence_service = (
    SegmentIntelligenceService()
)