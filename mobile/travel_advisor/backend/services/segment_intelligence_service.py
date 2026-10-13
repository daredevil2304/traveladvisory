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

    REPORT_LOOKBACK_HOURS = 24

    def evaluate_segment(
        self,
        db: Session,
        region: str,
        latitude: float,
        longitude: float,
        travel_datetime: datetime,
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

        # =========================================================
        # 2. Historical ML
        # =========================================================

        historical_prediction = (
            self._get_historical_prediction(
                region=normalized_region,
                travel_datetime=travel_datetime,
            )
        )

        historical_result = (
            historical_prediction.to_dict()
        )

        # =========================================================
        # 3. OpenWeather
        # =========================================================

        (
            weather_result,
            weather_dimensions,
        ) = self._get_weather_result(
            latitude=latitude,
            longitude=longitude,
        )

        # =========================================================
        # 4. Recent traveler reports
        # =========================================================

        reports = (
            traveler_report_retrieval_service.get_recent_reports(
                db=db,
                region=normalized_region,
                reference_datetime=travel_datetime,
                lookback_hours=self.REPORT_LOOKBACK_HOURS,
            )
        )

        serialized_reports = (
            traveler_report_retrieval_service.serialize_reports(
                reports
            )
        )

        report_dimensions = (
            self._build_report_dimensions(
                serialized_reports
            )
        )

        # =========================================================
        # 5. Dimension-aware fusion
        # =========================================================
        #
        # IMPORTANT:
        #
        # We do NOT collapse the sources into one condition.
        #
        # Example:
        #
        # Weather:
        #   rain       = Light Rain
        #   visibility = Very Clear
        #   fog        = None
        #
        # Traveler:
        #   rain       = Light Rain
        #   visibility = Poor
        #   unusual    = Landslide/Rockfall
        #
        # Each dimension remains independent.
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
        # 6. Segment Safety Score
        # =========================================================
        #
        # The Safety Score engine receives:
        #
        #   ML prediction
        #   normalized weather dimensions
        #   aggregated traveler dimensions
        #   fusion/evidence information
        #
        # Missing ML models are NOT converted into a fake score.
        # =========================================================

        safety_score = (
            safety_score_service.calculate_segment_score(
                historical_result=historical_result,
                weather_result=weather_dimensions,
                traveler_result=report_dimensions,
                fusion_result=fusion_result,
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
    ) -> PredictionResult:
        """
        Get the regional ML prediction.

        Feature construction remains deferred until the supplied
        regional models and their feature/output contract are known.

        No prediction is fabricated when the model is unavailable.
        """

        return prediction_service.predict(
            region=region,
            travel_datetime=travel_datetime,
            features=None,
        )

    # =============================================================
    # WEATHER
    # =============================================================

    def _get_weather_result(
        self,
        latitude: float,
        longitude: float,
    ) -> tuple[
        dict[str, Any] | None,
        dict[str, Any] | None,
    ]:
        """
        Retrieve and normalize OpenWeather information.

        Returns:

            weather_result:
                Complete normalized weather data.

            weather_dimensions:
                Dimension-level data passed into fusion and scoring.
        """

        try:
            weather: WeatherData = (
                weather_service.get_current_weather(
                    latitude=latitude,
                    longitude=longitude,
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
    ) -> dict[str, Any] | None:
        """
        Aggregate recent traveler observations by dimension.

        Each dimension is evaluated independently.

        Traffic is preserved in the original report but is NOT
        passed as a Safety Score dimension.
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
                }:
                    if value.casefold() == "none":
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