from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from typing import Any

from services.prediction_service import prediction_service
from services.route_segment_service import (
    resolve_route_segments,
    get_segment_details,
)


@dataclass(frozen=True)
class SegmentEvaluation:
    """
    Evaluation result for one route segment.
    """

    region: str
    status: str
    prediction: Any | None = None
    confidence: float | None = None
    model_available: bool = False
    model_name: str | None = None
    error: str | None = None

    def to_dict(self) -> dict:
        return {
            "region": self.region,
            "status": self.status,
            "prediction": self.prediction,
            "confidence": self.confidence,
            "model_available": self.model_available,
            "model_name": self.model_name,
            "error": self.error,
        }


@dataclass(frozen=True)
class RouteEvaluationResult:
    """
    Complete evaluation of all route segments between
    the selected source and destination.
    """

    source: str
    destination: str
    travel_datetime: datetime
    segments: list[SegmentEvaluation]

    def to_dict(self) -> dict:
        return {
            "source": self.source,
            "destination": self.destination,
            "travel_datetime": self.travel_datetime.isoformat(),
            "segment_count": len(self.segments),
            "segments": [
                segment.to_dict()
                for segment in self.segments
            ],
        }


class RouteEvaluationService:
    """
    Evaluates every route segment between a source and destination.

    Responsibilities:
    - Resolve the source/destination into R1-R7.
    - Preserve the correct travel direction.
    - Evaluate every relevant segment.
    - Call the regional PredictionService.

    This service does NOT:
    - calculate the final Safety Score
    - call OpenWeather
    - process traveler reports
    - perform consensus/fusion
    - generate alternate road routes
    """

    def evaluate_route(
        self,
        source: str,
        destination: str,
        travel_datetime: datetime,
    ) -> RouteEvaluationResult:
        """
        Evaluate every regional segment between source and destination.
        """

        if not isinstance(travel_datetime, datetime):
            raise ValueError(
                "travel_datetime must be a datetime object."
            )

        route_segments = resolve_route_segments(
            source,
            destination,
        )

        evaluations: list[SegmentEvaluation] = []

        for region in route_segments:
            evaluations.append(
                self._evaluate_segment(
                    region=region,
                    travel_datetime=travel_datetime,
                )
            )

        return RouteEvaluationResult(
            source=source,
            destination=destination,
            travel_datetime=travel_datetime,
            segments=evaluations,
        )

    def _evaluate_segment(
        self,
        region: str,
        travel_datetime: datetime,
    ) -> SegmentEvaluation:
        """
        Evaluate one regional segment.

        The model-specific feature construction is intentionally
        deferred until the actual regional models are supplied.
        """

        prediction = prediction_service.predict(
            region=region,
            travel_datetime=travel_datetime,
            features=None,
        )

        return SegmentEvaluation(
            region=prediction.region,
            status=prediction.status,
            prediction=prediction.prediction,
            confidence=prediction.confidence,
            model_available=prediction.model_available,
            model_name=prediction.model_name,
            error=prediction.error,
        )

    @staticmethod
    def get_route_segment_details(
        source: str,
        destination: str,
    ) -> list[dict]:
        """
        Return metadata for all route segments involved in a trip.

        This is separate from ML evaluation and is useful for
        displaying route information in the API/UI.
        """

        route_segments = resolve_route_segments(
            source,
            destination,
        )

        details: list[dict] = []

        for region in route_segments:
            segment = get_segment_details(region)

            if isinstance(segment, dict):
                details.append(segment)
            else:
                details.append(
                    {
                        "region": region,
                        "details": str(segment),
                    }
                )

        return details


# Shared service instance used by the backend.
route_evaluation_service = RouteEvaluationService()