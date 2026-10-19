from __future__ import annotations

from dataclasses import dataclass
from typing import Any


@dataclass(frozen=True)
class DimensionConsensus:
    """
    Consensus result for one intelligence dimension.

    Example dimensions:
        rain
        visibility
        fog
        unusual_conditions
        risk
    """

    dimension: str
    consensus: Any | None
    agreement_count: int
    available_source_count: int
    total_source_count: int
    agreement_ratio: float | None
    source_coverage: float
    agreeing_sources: list[str]
    status: str

    def to_dict(self) -> dict:
        return {
            "dimension": self.dimension,
            "consensus": self.consensus,
            "agreement_count": self.agreement_count,
            "available_source_count": self.available_source_count,
            "total_source_count": self.total_source_count,
            "agreement_ratio": self.agreement_ratio,
            "source_coverage": self.source_coverage,
            "agreeing_sources": self.agreeing_sources,
            "status": self.status,
        }


@dataclass(frozen=True)
class FusionResult:
    """
    Complete dimension-aware fusion result.

    Raw source outputs are preserved.

    Normalized source outputs are stored separately.

    Consensus is calculated independently for each dimension.
    """

    raw_sources: dict[str, Any]
    normalized_sources: dict[str, dict[str, Any]]
    dimension_consensus: dict[str, dict[str, Any]]
    status: str

    def to_dict(self) -> dict:
        return {
            "raw_sources": self.raw_sources,
            "normalized_sources": self.normalized_sources,
            "dimension_consensus": self.dimension_consensus,
            "status": self.status,
        }


class DataFusionService:
    """
    Dimension-aware, model-agnostic data fusion service.

    Current project rule:

        When at least 2 of the 3 independent sources agree on the
        same value for a particular dimension, that value becomes
        the consensus for that dimension.

    Sources:

        historical
        weather
        traveler

    The service deliberately does NOT assume the final ML model
    output format.
    """

    SOURCE_NAMES = (
        "historical",
        "weather",
        "traveler",
    )

    STANDARD_DIMENSIONS = (
        "rain",
        "visibility",
        "fog",
        "unusual_conditions",
        "risk",
    )

    def fuse(
        self,
        historical_result: Any | None,
        weather_result: Any | None,
        report_result: Any | None,
    ) -> FusionResult:
        """
        Perform dimension-aware fusion.

        Every source is processed independently.

        Consensus is calculated separately for each dimension.
        """

        raw_sources = {
            "historical": historical_result,
            "weather": weather_result,
            "traveler": report_result,
        }

        normalized_sources: dict[str, dict[str, Any]] = {}

        for source_name, source_value in raw_sources.items():
            normalized = self._normalize_source(
                source_name,
                source_value,
            )

            if normalized:
                normalized_sources[source_name] = normalized

        dimension_consensus: dict[str, dict[str, Any]] = {}

        for dimension in self.STANDARD_DIMENSIONS:
            result = self._fuse_dimension(
                dimension=dimension,
                normalized_sources=normalized_sources,
            )

            if result is not None:
                dimension_consensus[dimension] = (
                    result.to_dict()
                )

        if not normalized_sources:
            status = "no_sources_available"

        elif not dimension_consensus:
            status = "no_consensus"

        elif any(
            item["status"] == "consensus_reached"
            for item in dimension_consensus.values()
        ):
            status = "partial_or_full_consensus"

        else:
            status = "no_consensus"

        return FusionResult(
            raw_sources=raw_sources,
            normalized_sources=normalized_sources,
            dimension_consensus=dimension_consensus,
            status=status,
        )

    def fuse_conditions(
        self,
        historical_result: Any | None,
        weather_result: Any | None,
        report_result: Any | None,
    ) -> FusionResult:
        """
        Backward-compatible convenience method.
        """

        return self.fuse(
            historical_result=historical_result,
            weather_result=weather_result,
            report_result=report_result,
        )

    def _fuse_dimension(
        self,
        dimension: str,
        normalized_sources: dict[str, dict[str, Any]],
    ) -> DimensionConsensus | None:
        """
        Calculate consensus for one dimension.

        Only sources that actually contain that dimension are used.

        Agreement and source coverage are reported separately.

        agreement_ratio:
            Agreement among available sources.

            It is only calculated when at least two sources
            provide the dimension. With one available source,
            cross-source agreement cannot be established, so
            agreement_ratio is None.

        source_coverage:
            Percentage of the three expected sources that provide
            this dimension.
        """

        observations: dict[str, Any] = {}

        for source_name, source_data in normalized_sources.items():
            if dimension not in source_data:
                continue

            value = source_data[dimension]

            if value is None:
                continue

            normalized_value = self._normalize_value(
                value
            )

            if normalized_value is None:
                continue

            observations[source_name] = normalized_value

        total_source_count = len(self.SOURCE_NAMES)
        available_source_count = len(observations)

        if available_source_count == 0:
            return None

        groups: dict[str, list[str]] = {}

        original_values: dict[str, Any] = {}

        for source_name, value in observations.items():
            comparison_key = self._comparison_key(
                value
            )

            groups.setdefault(
                comparison_key,
                [],
            ).append(source_name)

            original_values.setdefault(
                comparison_key,
                value,
            )

        def get_source_weight(src: str) -> float:
            if dimension in ("rain", "visibility", "fog"):
                if src == "weather":
                    return 3.5  # OpenWeather API priority
                elif src == "traveler":
                    return 1.0
                return 1.2
            elif dimension in ("traffic", "congestion", "unusual_conditions", "risk"):
                if src in ("traffic", "google_maps"):
                    return 3.5  # Google Maps Telemetry priority
                elif src == "weather":
                    return 1.5
                elif src == "traveler":
                    return 1.0
                return 1.2
            else:
                return 1.0 if src == "traveler" else 1.5

        winning_key, agreeing_sources = max(
            groups.items(),
            key=lambda item: sum(get_source_weight(src) for src in item[1]),
        )

        agreement_count = len(agreeing_sources)
        weighted_agreement = sum(get_source_weight(src) for src in agreeing_sources)

        source_coverage = (
            available_source_count
            / total_source_count
        )

        # Cross-source agreement is meaningful only when
        # at least two sources are available.
        if available_source_count >= 2:
            agreement_ratio = (
                agreement_count
                / available_source_count
            )
        else:
            agreement_ratio = None

        if weighted_agreement >= 2.0:
            return DimensionConsensus(
                dimension=dimension,
                consensus=original_values[winning_key],
                agreement_count=agreement_count,
                available_source_count=available_source_count,
                total_source_count=total_source_count,
                agreement_ratio=agreement_ratio,
                source_coverage=round(
                    source_coverage,
                    4,
                ),
                agreeing_sources=agreeing_sources,
                status="consensus_reached",
            )

        return DimensionConsensus(
            dimension=dimension,
            consensus=None,
            agreement_count=agreement_count,
            available_source_count=available_source_count,
            total_source_count=total_source_count,
            agreement_ratio=agreement_ratio,
            source_coverage=round(
                source_coverage,
                4,
            ),
            agreeing_sources=agreeing_sources,
            status="no_consensus",
        )

    def _normalize_source(
        self,
        source_name: str,
        source: Any | None,
    ) -> dict[str, Any]:
        """
        Convert a source into the common dimension vocabulary.

        This method is deliberately conservative.

        It does not invent dimensions that are not present in
        the source.
        """

        if source is None:
            return {}

        source_data = self._to_dict(source)

        if isinstance(source, str):
            return {
                "risk": source,
            }

        if not source_data:
            return {}

        normalized: dict[str, Any] = {}

        # ---------------------------------------------------------
        # Direct standard dimensions
        # ---------------------------------------------------------

        for dimension in self.STANDARD_DIMENSIONS:
            if dimension in source_data:
                value = source_data.get(dimension)

                if value is not None:
                    normalized[dimension] = value

        # ---------------------------------------------------------
        # Common ML naming variants
        # ---------------------------------------------------------

        self._copy_first_available(
            source_data,
            normalized,
            "rain",
            (
                "rain_class",
                "rain_condition",
                "rainfall_class",
            ),
        )

        self._copy_first_available(
            source_data,
            normalized,
            "visibility",
            (
                "visibility_class",
                "visibility_condition",
            ),
        )

        self._copy_first_available(
            source_data,
            normalized,
            "fog",
            (
                "fog_class",
                "fog_condition",
            ),
        )

        self._copy_first_available(
            source_data,
            normalized,
            "unusual_conditions",
            (
                "unusual_condition",
                "road_condition",
            ),
        )

        self._copy_first_available(
            source_data,
            normalized,
            "risk",
            (
                "risk_class",
                "risk_level",
                "safety_class",
                "safety_level",
            ),
        )

        # ---------------------------------------------------------
        # Weather-specific fields
        # ---------------------------------------------------------

        if source_name == "weather":
            self._copy_first_available(
                source_data,
                normalized,
                "rain",
                (
                    "rain_condition",
                ),
            )

            self._copy_first_available(
                source_data,
                normalized,
                "visibility",
                (
                    "visibility_condition",
                ),
            )

            self._copy_first_available(
                source_data,
                normalized,
                "fog",
                (
                    "fog_condition",
                ),
            )

        # ---------------------------------------------------------
        # Traveler report-specific fields
        # ---------------------------------------------------------

        if source_name == "traveler":
            self._copy_first_available(
                source_data,
                normalized,
                "rain",
                (
                    "rain",
                ),
            )

            self._copy_first_available(
                source_data,
                normalized,
                "visibility",
                (
                    "visibility",
                ),
            )

            self._copy_first_available(
                source_data,
                normalized,
                "fog",
                (
                    "fog",
                ),
            )

            self._copy_first_available(
                source_data,
                normalized,
                "unusual_conditions",
                (
                    "unusual_conditions",
                ),
            )

        # ---------------------------------------------------------
        # Historical/model-specific fields
        # ---------------------------------------------------------

        if source_name == "historical":
            self._copy_first_available(
                source_data,
                normalized,
                "risk",
                (
                    "prediction",
                    "predicted_risk",
                    "predicted_safety",
                ),
            )

        return normalized

    @staticmethod
    def _copy_first_available(
        source_data: dict[str, Any],
        target: dict[str, Any],
        target_dimension: str,
        candidate_keys: tuple[str, ...],
    ) -> None:
        """
        Copy the first available candidate value into the
        standardized dimension.
        """

        if target_dimension in target:
            return

        for key in candidate_keys:
            if key not in source_data:
                continue

            value = source_data.get(key)

            if value is not None:
                target[target_dimension] = value
                return

    @staticmethod
    def _to_dict(
        value: Any,
    ) -> dict[str, Any]:
        """
        Convert common result objects into dictionaries.
        """

        if value is None:
            return {}

        if isinstance(value, dict):
            return value.copy()

        if hasattr(value, "to_dict"):
            converted = value.to_dict()

            if isinstance(converted, dict):
                return converted

        if hasattr(value, "__dict__"):
            return {
                key: item
                for key, item in vars(value).items()
                if not key.startswith("_")
            }

        return {}

    @staticmethod
    def _normalize_value(
        value: Any,
    ) -> Any | None:
        """
        Basic value normalization.

        Numeric values remain numeric.

        Strings are normalized for comparison while the original
        normalized string is retained as the consensus value.
        """

        if value is None:
            return None

        if isinstance(value, str):
            cleaned = value.strip()

            if not cleaned:
                return None

            return cleaned

        return value

    @staticmethod
    def _comparison_key(
        value: Any,
    ) -> str:
        """
        Produce a stable comparison representation.

        This prevents values such as:

            "Poor"
            "poor"
            " POOR "

        from being treated as different conditions.
        """

        if isinstance(value, str):
            return (
                value
                .strip()
                .lower()
                .replace("-", "_")
                .replace(" ", "_")
            )

        return str(value).strip().lower()


# Shared fusion service instance.
data_fusion_service = DataFusionService()