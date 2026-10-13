from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from typing import Any

from ml.model_loader import ModelLoadError, model_loader


@dataclass(frozen=True)
class PredictionResult:
    """
    Standardized result returned by the regional ML prediction layer.

    This structure intentionally does not assume what algorithm,
    feature set, or prediction labels the final ML models will use.
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


class PredictionService:
    """
    Model-agnostic regional prediction service.

    Responsibilities:
    - Validate the requested route region.
    - Check whether a regional model exists.
    - Load the model through ModelLoader.
    - Execute prediction when the model contract is known.
    - Return a standardized PredictionResult.

    This service deliberately does NOT handle:
    - OpenWeather
    - Traveler reports
    - Data fusion
    - Safety scoring
    - Route generation
    - LLM responses

    Those responsibilities belong to separate layers.
    """

    SUPPORTED_REGIONS = {
        "R1",
        "R2",
        "R3",
        "R4",
        "R5",
        "R6",
        "R7",
    }

    def __init__(self) -> None:
        self._model_loader = model_loader

    def check_model(self, region: str) -> PredictionResult:
        """
        Check whether a model is currently available for a region.

        No model is loaded or executed by this method.
        """
        normalized_region = self._normalize_region(region)

        if normalized_region not in self.SUPPORTED_REGIONS:
            return PredictionResult(
                region=normalized_region,
                status="invalid_region",
                error=(
                    f"Unsupported route region: {normalized_region}. "
                    f"Expected one of: "
                    f"{', '.join(sorted(self.SUPPORTED_REGIONS))}."
                ),
            )

        try:
            available = self._model_loader.is_model_available(
                normalized_region
            )
        except Exception as exc:
            return PredictionResult(
                region=normalized_region,
                status="availability_check_failed",
                error=str(exc),
            )

        if not available:
            return PredictionResult(
                region=normalized_region,
                status="model_unavailable",
                model_available=False,
                error=(
                    f"No ML model is currently available for "
                    f"region {normalized_region}."
                ),
            )

        return PredictionResult(
            region=normalized_region,
            status="model_available",
            model_available=True,
        )

    def predict(
        self,
        region: str,
        travel_datetime: datetime,
        features: Any | None = None,
    ) -> PredictionResult:
        """
        Execute a regional prediction.

        The actual feature-to-model mapping will be implemented after
        the ML models are supplied and their input/output contract is
        known.

        Until then, this method safely reports that prediction
        execution is not configured instead of generating fake results.
        """
        normalized_region = self._normalize_region(region)

        if normalized_region not in self.SUPPORTED_REGIONS:
            return PredictionResult(
                region=normalized_region,
                status="invalid_region",
                error=(
                    f"Unsupported route region: {normalized_region}."
                ),
            )

        if not isinstance(travel_datetime, datetime):
            return PredictionResult(
                region=normalized_region,
                status="invalid_datetime",
                error="travel_datetime must be a datetime object.",
            )

        try:
            model = self._model_loader.load_model(normalized_region)
        except ModelLoadError as exc:
            return PredictionResult(
                region=normalized_region,
                status="model_unavailable",
                model_available=False,
                error=str(exc),
            )
        except Exception as exc:
            return PredictionResult(
                region=normalized_region,
                status="model_load_failed",
                model_available=False,
                error=str(exc),
            )

        model_name = type(model).__name__

        # -------------------------------------------------------------
        # IMPORTANT:
        #
        # Do not assume the model's feature schema or prediction
        # interface yet.
        #
        # Your friends will provide the regional models later.
        # Once their model contract is available, this section will
        # call the appropriate prediction interface.
        # -------------------------------------------------------------

        return PredictionResult(
            region=normalized_region,
            status="model_loaded_prediction_not_configured",
            prediction=None,
            confidence=None,
            model_available=True,
            model_name=model_name,
            error=(
                "The regional model was loaded successfully, but its "
                "feature schema and prediction contract have not yet "
                "been configured."
            ),
        )

    @staticmethod
    def _normalize_region(region: str) -> str:
        """
        Normalize a route-region identifier.
        """
        if not isinstance(region, str):
            return ""

        return region.strip().upper()


# Shared service instance used by the backend.
prediction_service = PredictionService()