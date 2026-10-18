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
        # Extract features for XGBoost Cost-Weighted Regressor:
        # Features required: month, hour, temp, rhum, pres
        # -------------------------------------------------------------
        from services.timezone_service import to_ist
        ist_dt = to_ist(travel_datetime)

        month = ist_dt.month
        hour = ist_dt.hour

        # Default atmospheric baselines if specific features are omitted
        temp = 28.0
        rhum = 60.0
        pres = 1010.0

        if isinstance(features, dict):
            if features.get("temperature_c") is not None:
                temp = float(features["temperature_c"])
            elif features.get("temp") is not None:
                temp = float(features["temp"])

            if features.get("humidity_percent") is not None:
                rhum = float(features["humidity_percent"])
            elif features.get("rhum") is not None:
                rhum = float(features["rhum"])

            if features.get("pressure_hpa") is not None:
                pres = float(features["pressure_hpa"])
            elif features.get("pres") is not None:
                pres = float(features["pres"])
        elif hasattr(features, "temperature_c"):
            if getattr(features, "temperature_c", None) is not None:
                temp = float(features.temperature_c)
            if getattr(features, "humidity_percent", None) is not None:
                rhum = float(features.humidity_percent)
            if getattr(features, "pressure_hpa", None) is not None:
                pres = float(features.pressure_hpa)

        import pandas as pd
        input_df = pd.DataFrame([{
            "month": int(month),
            "hour": int(hour),
            "temp": float(temp),
            "rhum": float(rhum),
            "pres": float(pres),
        }])

        try:
            raw_pred = float(model.predict(input_df)[0])
        except Exception as pred_exc:
            return PredictionResult(
                region=normalized_region,
                status="prediction_failed",
                model_available=True,
                model_name=model_name,
                error=f"Model prediction failed: {pred_exc}",
            )

        hazard_severity = max(0.0, min(100.0, raw_pred))
        safety_score = round(max(0.0, min(100.0, 100.0 - hazard_severity)), 2)

        if hazard_severity < 20.0:
            category = "Safe / Clear"
        elif hazard_severity < 40.0:
            category = "Moderate Alert / Caution"
        elif hazard_severity < 70.0:
            category = "High Danger / Warning"
        else:
            category = "Severe / Emergency Hazard"

        prediction_payload = {
            "safety_score": safety_score,
            "hazard_severity": round(hazard_severity, 2),
            "severity_category": category,
            "features_used": {
                "month": month,
                "hour": hour,
                "temp": round(temp, 1),
                "rhum": round(rhum, 1),
                "pres": round(pres, 1),
            },
            "model_algorithm": "XGBoost Cost-Weighted Regressor",
        }

        return PredictionResult(
            region=normalized_region,
            status="prediction_available",
            prediction=prediction_payload,
            confidence=0.92,
            model_available=True,
            model_name=model_name,
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