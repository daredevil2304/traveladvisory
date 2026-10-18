from __future__ import annotations

from dataclasses import dataclass
from typing import Any


@dataclass(frozen=True)
class SafetyScoreResult:
    """
    Safety assessment for one route segment.

    safety_score:
        0-100, where higher means safer conditions.

    confidence:
        0-100 evidence/coverage confidence. This is deliberately
        separate from the Safety Score.

    The service does not treat missing information as unsafe.
    """

    safety_score: float | None
    confidence: float
    status: str

    ml_score: float | None
    weather_score: float | None
    traveler_score: float | None
    evidence_score: float | None
    traffic_score: float | None = None
    terrain_score: float | None = None

    available_sources: list[str] = ()
    missing_sources: list[str] = ()

    dimension_scores: dict[str, float] = None
    reasons: list[str] = None
    risk_factors: list[str] = None

    def to_dict(self) -> dict[str, Any]:
        return {
            "safety_score": self.safety_score,
            "confidence": self.confidence,
            "status": self.status,
            "ml_score": self.ml_score,
            "weather_score": self.weather_score,
            "traveler_score": self.traveler_score,
            "evidence_score": self.evidence_score,
            "traffic_score": self.traffic_score,
            "terrain_score": self.terrain_score,
            "components": {
                "ml_score": self.ml_score,
                "weather_score": self.weather_score,
                "traveler_score": self.traveler_score,
                "evidence_score": self.evidence_score,
                "traffic_score": self.traffic_score,
                "terrain_score": self.terrain_score,
            },
            "available_sources": list(self.available_sources or []),
            "missing_sources": list(self.missing_sources or []),
            "dimension_scores": self.dimension_scores or {},
            "reasons": self.reasons or [],
            "risk_factors": list(self.risk_factors or []),
        }


class SafetyScoreService:
    """
    Calculates a transparent segment-level Safety Score.

    Design principles:

    1. Higher score = safer conditions.
    2. Missing data is NOT treated as zero safety.
    3. Safety Score and confidence are separate.
    4. Traffic is deliberately excluded.
    5. Dimension-level conditions are evaluated independently.
    6. ML output is accepted only when it can be interpreted
       without inventing semantics.
    7. All scoring rules are centralized here so they can later
       be calibrated using validation data.
    """

    # -------------------------------------------------------------
    # Source weights
    # -------------------------------------------------------------
    #
    # These are INITIAL RESEARCH WEIGHTS.
    #
    # They are configuration hypotheses, not scientifically
    # validated final weights.
    #
    # ML        = 40%
    # Weather   = 30%
    # Traveler  = 20%
    # Evidence  = 10%
    #
    # The weights are normalized automatically whenever a source
    # is unavailable.
    # -------------------------------------------------------------

    # -------------------------------------------------------------
    # Calibrated Source Weights
    # -------------------------------------------------------------
    # Traveler Profile (En-route traveling right now):
    #   ML Historical Model  = 30%
    #   Live Weather          = 25%
    #   Live Traffic          = 25%
    #   Community Hazard Reports = 20%
    # Dynamic normalization applies if community reports are absent
    # (ML: 37.5%, Weather: 31.25%, Traffic: 31.25%).
    # -------------------------------------------------------------
    TRAVELER_SOURCE_WEIGHTS = {
        "ml": 0.30,
        "weather": 0.25,
        "traffic": 0.25,
        "traveler": 0.20,
    }

    # -------------------------------------------------------------
    # Planner Profile (Advance trip planning):
    #   Traffic is strictly 0.00 (excluded).
    #   ML Forecast Prediction = 45%
    #   OpenWeather Forecast   = 35%
    #   Terrain & Schedule     = 20%
    # -------------------------------------------------------------
    PLANNER_SOURCE_WEIGHTS = {
        "ml": 0.45,
        "weather": 0.35,
        "terrain": 0.20,
        "traffic": 0.00,
        "traveler": 0.00,
    }

    SOURCE_WEIGHTS = TRAVELER_SOURCE_WEIGHTS

    # -------------------------------------------------------------
    # Weather condition safety values
    # -------------------------------------------------------------

    RAIN_SCORES = {
        "no rain": 100.0,
        "drizzle": 95.0,
        "light rain": 85.0,
        "moderate rain": 70.0,
        "heavy rain": 45.0,
        "very heavy rain": 20.0,
    }

    VISIBILITY_SCORES = {
        "very clear": 100.0,
        "clear": 95.0,
        "slightly reduced": 85.0,
        "moderately reduced": 70.0,
        "poor": 45.0,
        "very poor": 20.0,
    }

    FOG_SCORES = {
        "none": 100.0,
        "light mist": 90.0,
        "moderate mist": 75.0,
        "dense fog": 40.0,
        "very dense fog": 15.0,
    }

    # -------------------------------------------------------------
    # Traveler-reported unusual conditions
    # -------------------------------------------------------------

    UNUSUAL_CONDITION_SCORES = {
        "none": 100.0,
        "slippery_road": 65.0,
        "slippery road": 65.0,
        "debris on road": 45.0,
        "debris_on_road": 45.0,
        "road damage": 50.0,
        "road_damage": 50.0,
        "construction activity": 70.0,
        "construction_activity": 70.0,
        "fallen tree": 40.0,
        "fallen_tree": 40.0,
        "accident/incident": 40.0,
        "accident_incident": 40.0,
        "landslide/rockfall": 25.0,
        "landslide_rockfall": 25.0,
        "flooding": 20.0,
        "road closure": 0.0,
        "road_closure": 0.0,
        "other": 60.0,
    }

    # -------------------------------------------------------------
    # Public API
    # -------------------------------------------------------------

    def calculate_segment_score(
        self,
        *,
        historical_result: dict[str, Any] | None = None,
        weather_result: dict[str, Any] | None = None,
        traveler_result: dict[str, Any] | None = None,
        fusion_result: dict[str, Any] | None = None,
        traffic_result: dict[str, Any] | None = None,
        is_planner: bool = False,
        terrain_score: float | None = None,
        terrain_reasons: list[str] | None = None,
    ) -> SafetyScoreResult:
        """
        Calculate a fair, calibrated Safety Score for one route segment.

        Traveler Profile:
            - ML Historical Model (30%)
            - Live Weather (25%)
            - Live Traffic (25%)
            - Community Reports (20%)

        Planner Profile:
            - ML Forecast Model (45%)
            - Forecast Weather (35%)
            - Terrain Geometry & Schedule (20%)
            - Traffic is strictly 0% (excluded)
        """

        # 1. Component calculations
        ml_score = self._calculate_ml_score(historical_result)
        weather_score, weather_dimensions = self._calculate_weather_score(weather_result)
        evidence_score = self._calculate_evidence_score(fusion_result)

        dimension_scores: dict[str, float] = {}
        dimension_scores.update(weather_dimensions)

        if is_planner:
            # Planner Mode: Traffic is strictly excluded (0% weight)
            active_weights = self.PLANNER_SOURCE_WEIGHTS
            traffic_score = None
            traffic_dimensions = {}
            traveler_score = None
            traveler_dimensions = {}
            terrain_val, terrain_dims = self._calculate_terrain_score(terrain_score)
            dimension_scores.update(terrain_dims)

            source_scores = {
                "ml": ml_score,
                "weather": weather_score,
                "terrain": terrain_val,
            }
        else:
            # Traveler Mode: Live traffic and community reports included
            active_weights = self.TRAVELER_SOURCE_WEIGHTS
            traffic_score, traffic_dimensions = self._calculate_traffic_score(traffic_result)
            traveler_score, traveler_dimensions = self._calculate_traveler_score(traveler_result)
            terrain_val = None
            terrain_dims = {}
            dimension_scores.update(traveler_dimensions)
            dimension_scores.update(traffic_dimensions)

            source_scores = {
                "ml": ml_score,
                "weather": weather_score,
                "traffic": traffic_score,
                "traveler": traveler_score,
            }

        if ml_score is not None:
            dimension_scores["ml_prediction"] = ml_score

        # 2. Determine available and missing sources
        available_sources = [
            source
            for source, score in source_scores.items()
            if score is not None
        ]

        missing_sources = [
            source
            for source, score in source_scores.items()
            if score is None
        ]

        # 3. Calculate weighted score
        safety_score = self._weighted_score(
            source_scores,
            weights=active_weights,
        )

        # 4. Critical Hazard Floor Override
        # If an active catastrophic hazard is reported (road closure, severe landslide, flooding),
        # cap the segment score at that hazard's floor so high scores elsewhere cannot mask it.
        if traveler_dimensions.get("unusual_conditions") is not None:
            unusual_val = traveler_dimensions["unusual_conditions"]
            if unusual_val < 35.0 and safety_score is not None:
                safety_score = min(safety_score, unusual_val)

        # 5. Generate human-readable reasons
        reasons = self._generate_reasons(
            weather_result=weather_result,
            traveler_result=traveler_result,
            dimension_scores=dimension_scores,
        )

        # Append Traffic reason (Traveler mode)
        if not is_planner and isinstance(traffic_result, dict):
            delay = traffic_result.get("delay_minutes", 0)
            status_lbl = traffic_result.get("status_label", "Normal Flow")
            speed_adv = traffic_result.get("speed_advice", "80-100 km/h")
            if delay > 0 or traffic_result.get("congestion_level") in ("moderate", "heavy", "standstill"):
                reasons.append(
                    f"Traffic flow: {status_lbl} (~{delay}m delay, cruising speed {speed_adv})."
                )
            else:
                reasons.append(
                    f"Traffic flow: Optimal fluid transit ({speed_adv}, no delays reported)."
                )

        # Append Terrain & Planner reasons
        if is_planner and terrain_reasons:
            reasons.extend(terrain_reasons)

        # 6. Extract genuine risk factors (strictly negative conditions, empty when safe)
        risk_factors: list[str] = []

        if isinstance(weather_result, dict):
            rain = weather_result.get("rain")
            rain_mm = weather_result.get("rainfall_mm")
            if isinstance(rain, str) and rain.casefold() not in {"no rain", "none"}:
                r_det = f" ({rain_mm} mm)" if rain_mm and rain_mm > 0 else ""
                risk_factors.append(f"Precipitation: {rain}{r_det}. Wet road surface.")

            vis = weather_result.get("visibility")
            if isinstance(vis, str) and vis.casefold() in {"poor", "very poor", "moderately reduced"}:
                vis_km = weather_result.get("visibility_km")
                v_det = f" ({vis_km} km)" if vis_km else ""
                risk_factors.append(f"Reduced visibility: {vis}{v_det}.")

            fog = weather_result.get("fog")
            if isinstance(fog, str) and fog.casefold() not in {"none"}:
                risk_factors.append(f"Fog hazard: {fog} reported on stretch.")

        if isinstance(traveler_result, dict):
            unusual = traveler_result.get("unusual_conditions")
            if isinstance(unusual, str) and unusual.casefold() not in {"none", "nothing unusual"}:
                risk_factors.append(f"Road hazard: {unusual}.")

        # Traffic delay / bottleneck risk
        if not is_planner and isinstance(traffic_result, dict):
            delay = traffic_result.get("delay_minutes", 0)
            congestion = str(traffic_result.get("congestion_level", "")).lower()
            status_lbl = traffic_result.get("status_label", "")
            speed_adv = traffic_result.get("speed_advice", "")
            if delay >= 5 or congestion in ("moderate", "heavy", "standstill"):
                risk_factors.append(
                    f"Traffic bottleneck: {status_lbl} (~{delay}m delay, speed {speed_adv})."
                )

        # Inherent steep terrain or night driving risks (only flagged as risk factors when overall safety is degraded < 85)
        if terrain_reasons and (safety_score is None or safety_score < 85.0):
            for tr in terrain_reasons:
                tr_lower = tr.lower()
                if "steep bhor ghat" in tr_lower:
                    risk_factors.append("Steep mountain gradient: low gear and truck clearance advised.")
                elif "night travel window" in tr_lower:
                    risk_factors.append("Night driving: reduced ambient visibility on unlit expressway sections.")

        # 7. Confidence
        confidence = self._calculate_confidence(
            source_scores=source_scores,
            fusion_result=fusion_result,
        )

        # 8. Status
        status = self._determine_status(
            safety_score=safety_score,
            available_sources=available_sources,
            confidence=confidence,
        )

        return SafetyScoreResult(
            safety_score=safety_score,
            confidence=confidence,
            status=status,
            ml_score=ml_score,
            weather_score=weather_score,
            traveler_score=traveler_score,
            evidence_score=evidence_score,
            traffic_score=traffic_score,
            terrain_score=terrain_val,
            available_sources=available_sources,
            missing_sources=missing_sources,
            dimension_scores=dimension_scores,
            reasons=reasons,
            risk_factors=risk_factors,
        )

    # =============================================================
    # WEATHER
    # =============================================================

    def _calculate_weather_score(
        self,
        weather_result: dict[str, Any] | None,
    ) -> tuple[
        float | None,
        dict[str, float],
    ]:
        """
        Calculate the weather component.

        Rain, visibility and fog are scored independently.

        The resulting weather score is the average of available
        dimensions. Missing dimensions are not treated as unsafe.
        """

        if not isinstance(weather_result, dict):
            return None, {}

        dimensions: dict[str, float] = {}

        rain = weather_result.get("rain")

        if isinstance(rain, str):
            score = self._lookup_score(
                rain,
                self.RAIN_SCORES,
            )

            if score is not None:
                dimensions["rain"] = score

        visibility = weather_result.get("visibility")

        if isinstance(visibility, str):
            score = self._lookup_score(
                visibility,
                self.VISIBILITY_SCORES,
            )

            if score is not None:
                dimensions["visibility"] = score

        fog = weather_result.get("fog")

        if isinstance(fog, str):
            score = self._lookup_score(
                fog,
                self.FOG_SCORES,
            )

            if score is not None:
                dimensions["fog"] = score

        if not dimensions:
            return None, {}

        return (
            self._average(
                list(dimensions.values())
            ),
            dimensions,
        )

    # =============================================================
    # TRAVELER REPORTS
    # =============================================================

    def _calculate_traveler_score(
        self,
        traveler_result: dict[str, Any] | None,
    ) -> tuple[
        float | None,
        dict[str, float],
    ]:
        """
        Calculate the traveler-observation component.

        Traffic is explicitly ignored.

        Traveler dimensions:

            rain
            visibility
            fog
            unusual_conditions

        Traffic is stored elsewhere but must not affect Safety Score.
        """

        if not isinstance(traveler_result, dict):
            return None, {}

        dimensions: dict[str, float] = {}

        rain = traveler_result.get("rain")

        if isinstance(rain, str):
            score = self._lookup_score(
                rain,
                self.RAIN_SCORES,
            )

            if score is not None:
                dimensions["traveler_rain"] = score

        visibility = traveler_result.get("visibility")

        if isinstance(visibility, str):
            score = self._lookup_score(
                visibility,
                self.VISIBILITY_SCORES,
            )

            if score is not None:
                dimensions["traveler_visibility"] = score

        fog = traveler_result.get("fog")

        if isinstance(fog, str):
            score = self._lookup_score(
                fog,
                self.FOG_SCORES,
            )

            if score is not None:
                dimensions["traveler_fog"] = score

        unusual = traveler_result.get(
            "unusual_conditions"
        )

        if isinstance(unusual, str):
            score = self._lookup_score(
                unusual,
                self.UNUSUAL_CONDITION_SCORES,
            )

            if score is not None:
                dimensions[
                    "unusual_conditions"
                ] = score

        # Deliberately DO NOT read traveler_result["traffic"].

        if not dimensions:
            return None, {}

        return (
            self._average(
                list(dimensions.values())
            ),
            dimensions,
        )

    # =============================================================
    # ML
    # =============================================================

    def _calculate_ml_score(
        self,
        historical_result: dict[str, Any] | None,
    ) -> float | None:
        """
        Interpret a regional ML prediction only when its output is
        already expressed in a recognized safety/risk representation.

        We do NOT assume that an arbitrary numeric prediction means
        safety, probability, rainfall, nor risk.

        Supported explicit fields:

            safety_score
            safety
            safety_level
            risk_score
            risk_level
            predicted_safety

        If the model exposes another schema, this method returns
        None until that model contract is explicitly mapped.
        """

        if not isinstance(
            historical_result,
            dict,
        ):
            return None

        prediction = historical_result.get(
            "prediction"
        )

        if prediction is None:
            return None

        if isinstance(prediction, dict):
            return self._interpret_ml_dict(
                prediction
            )

        # A bare numeric model output has ambiguous semantics.
        # Do not invent an interpretation.
        return None

    def _interpret_ml_dict(
        self,
        prediction: dict[str, Any],
    ) -> float | None:
        """
        Interpret an explicitly named ML safety/risk field.
        """

        # ---------------------------------------------------------
        # Direct safety score
        # ---------------------------------------------------------

        for key in (
            "safety_score",
            "predicted_safety",
        ):
            value = prediction.get(key)

            score = self._numeric_0_100(
                value
            )

            if score is not None:
                return score

        # ---------------------------------------------------------
        # Explicit safety level
        # ---------------------------------------------------------

        for key in (
            "safety",
            "safety_level",
        ):
            value = prediction.get(key)

            score = self._safety_level_to_score(
                value
            )

            if score is not None:
                return score

        # ---------------------------------------------------------
        # Explicit risk score
        #
        # Higher risk means lower safety.
        # ---------------------------------------------------------

        value = prediction.get(
            "risk_score"
        )

        risk_score = self._numeric_0_100(
            value
        )

        if risk_score is not None:
            return 100.0 - risk_score

        # ---------------------------------------------------------
        # Explicit risk level
        # ---------------------------------------------------------

        value = prediction.get(
            "risk_level"
        )

        risk_score = self._risk_level_to_score(
            value
        )

        if risk_score is not None:
            return 100.0 - risk_score

        return None

    # =============================================================
    # EVIDENCE / CONSENSUS
    # =============================================================

    def _calculate_evidence_score(
        self,
        fusion_result: dict[str, Any] | None,
    ) -> float | None:
        """
        Calculate evidence-strength score from the dimension-aware
        fusion result.

        This is NOT the same thing as Safety Score.

        The purpose is to represent how strongly available sources
        agree.

        Agreement is separated from source coverage where possible.
        """

        if not isinstance(
            fusion_result,
            dict,
        ):
            return None

        consensus = fusion_result.get(
            "dimension_consensus"
        )

        if not isinstance(
            consensus,
            dict,
        ):
            return None

        scores: list[float] = []

        for value in consensus.values():

            if not isinstance(
                value,
                dict,
            ):
                continue

            # Prefer explicit agreement_ratio.
            agreement_ratio = value.get(
                "agreement_ratio"
            )

            if isinstance(
                agreement_ratio,
                (int, float),
            ):
                ratio = float(
                    agreement_ratio
                )

                if 0.0 <= ratio <= 1.0:
                    scores.append(
                        ratio * 100.0
                    )
                    continue

            # Fall back to the existing confidence field.
            confidence = value.get(
                "confidence"
            )

            if isinstance(
                confidence,
                (int, float),
            ):
                value_float = float(
                    confidence
                )

                if 0.0 <= value_float <= 1.0:
                    scores.append(
                        value_float * 100.0
                    )
                elif 0.0 <= value_float <= 100.0:
                    scores.append(
                        value_float
                    )

        if not scores:
            return None

        return self._average(
            scores
        )

    # =============================================================
    # TRAFFIC & TERRAIN HELPERS
    # =============================================================

    def _calculate_traffic_score(
        self,
        traffic_result: dict[str, Any] | None,
    ) -> tuple[float | None, dict[str, float]]:
        if not isinstance(traffic_result, dict):
            return None, {}

        # If explicit traffic_score already exists
        if "traffic_score" in traffic_result and isinstance(traffic_result["traffic_score"], (int, float)):
            ts = float(traffic_result["traffic_score"])
            return ts, {"live_traffic": ts}

        delay = traffic_result.get("delay_minutes", 0)
        congestion = str(traffic_result.get("congestion_level", "free_flow")).lower()

        if congestion == "standstill" or delay >= 25:
            score = 40.0
        elif congestion == "heavy" or delay >= 15:
            score = 60.0
        elif congestion == "moderate" or delay >= 6:
            score = 75.0
        elif delay >= 3:
            score = 86.0
        elif delay >= 1:
            score = 94.0
        else:
            score = 98.0

        return score, {"live_traffic": score}

    def _calculate_terrain_score(
        self,
        terrain_score: float | None,
    ) -> tuple[float | None, dict[str, float]]:
        if terrain_score is None:
            return None, {}
        t_val = float(terrain_score)
        return t_val, {"terrain_geometry": t_val}

    # =============================================================
    # WEIGHTED SAFETY SCORE
    # =============================================================

    def _weighted_score(
        self,
        source_scores: dict[str, float | None],
        weights: dict[str, float] | None = None,
    ) -> float | None:
        """
        Calculate weighted Safety Score using only available sources.

        Missing sources are excluded and the remaining weights are
        normalized.
        """
        if weights is None:
            weights = self.SOURCE_WEIGHTS

        available = {
            source: score
            for source, score in source_scores.items()
            if score is not None and weights.get(source, 0.0) > 0.0
        }

        if not available:
            return None

        total_weight = sum(
            weights.get(source, 0.0)
            for source in available
        )

        if total_weight <= 0:
            return None

        weighted_total = 0.0

        for source, score in available.items():
            normalized_weight = (
                weights.get(source, 0.0)
                / total_weight
            )
            weighted_total += (
                float(score)
                * normalized_weight
            )

        return round(
            max(
                0.0,
                min(
                    100.0,
                    weighted_total,
                ),
            ),
            1,
        )

    # =============================================================
    # CONFIDENCE
    # =============================================================

    def _calculate_confidence(
        self,
        source_scores: dict[str, float | None],
        fusion_result: dict[str, Any] | None,
    ) -> float:
        """
        Calculate evidence/coverage confidence separately from
        Safety Score.

        Confidence considers:

            1. Source coverage
            2. Dimension agreement

        It does NOT increase merely because the Safety Score is high.
        """

        available_count = sum(
            score is not None
            for score in source_scores.values()
        )

        source_coverage = (
            available_count
            / len(source_scores)
        )

        agreement_score = (
            self._calculate_evidence_score(
                fusion_result
            )
        )

        if agreement_score is None:
            # No fusion evidence available.
            # Confidence reflects only source coverage.
            return round(
                source_coverage * 100.0,
                2,
            )

        # ---------------------------------------------------------
        # Coverage contributes 50%.
        # Agreement contributes 50%.
        # ---------------------------------------------------------

        confidence = (
            (source_coverage * 100.0 * 0.50)
            + (agreement_score * 0.50)
        )

        return round(
            max(
                0.0,
                min(
                    100.0,
                    confidence,
                ),
            ),
            2,
        )

    # =============================================================
    # REASONS
    # =============================================================

    def _generate_reasons(
        self,
        *,
        weather_result: dict[str, Any] | None,
        traveler_result: dict[str, Any] | None,
        dimension_scores: dict[str, float],
    ) -> list[str]:
        """
        Generate deterministic reasons from observed conditions.

        These reasons are descriptive. They do not replace the
        Safety Score calculation and should not be generated by the
        LLM.
        """

        reasons: list[str] = []

        temp = (
            weather_result.get("temperature_c")
            if isinstance(weather_result, dict)
            else None
        )
        cond = (
            weather_result.get("weather_condition", "Clear")
            if isinstance(weather_result, dict)
            else "Clear"
        )
        wind = (
            weather_result.get("wind_speed_kmh")
            if isinstance(weather_result, dict)
            else None
        )
        rain_mm = (
            weather_result.get("rainfall_mm")
            if isinstance(weather_result, dict)
            else None
        )

        # ---------------------------------------------------------
        # Weather reasons
        # ---------------------------------------------------------

        if isinstance(weather_result, dict):
            rain = weather_result.get("rain")
            if isinstance(rain, str) and rain.casefold() not in {
                "no rain",
                "none",
            }:
                rain_detail = (
                    f" ({rain_mm} mm)"
                    if rain_mm and rain_mm > 0
                    else ""
                )
                reasons.append(
                    f"Weather indicates {rain}{rain_detail}. Reduce speed for wet asphalt."
                )

            visibility = weather_result.get("visibility")
            if isinstance(visibility, str) and visibility.casefold() in {
                "poor",
                "very poor",
                "moderately reduced",
            }:
                vis_km = weather_result.get("visibility_km")
                vis_detail = (
                    f" ({vis_km} km)"
                    if vis_km
                    else ""
                )
                reasons.append(
                    f"Reduced visibility observed{vis_detail}. Maintain safe following distance."
                )

            fog = weather_result.get("fog")
            if isinstance(fog, str) and fog.casefold() not in {
                "none",
            }:
                reasons.append(
                    f"Fog and mist detected ({fog}). Use low-beam headlamps."
                )

            if wind is not None and wind > 35:
                reasons.append(
                    f"Elevated wind gusts of {round(wind)} km/h along this stretch."
                )

        # ---------------------------------------------------------
        # Traveler reasons
        # ---------------------------------------------------------

        if isinstance(traveler_result, dict):
            unusual = traveler_result.get("unusual_conditions")
            if isinstance(unusual, str) and unusual.casefold() not in {
                "none",
                "nothing unusual",
            }:
                reasons.append(
                    f"Traveler reports indicate {unusual}."
                )

            visibility = traveler_result.get("visibility")
            if isinstance(visibility, str) and visibility.casefold() in {
                "poor",
                "very poor",
                "moderately reduced",
            }:
                reasons.append(
                    f"Traveler reports indicate {visibility} visibility."
                )

            traffic = traveler_result.get("traffic")
            if isinstance(traffic, str) and traffic.casefold() in {
                "heavy",
                "very heavy",
                "standstill",
            }:
                reasons.append(
                    f"Traffic flow reported as {traffic}."
                )

        # ---------------------------------------------------------
        # Dynamic clear-condition affirmative reasoning
        # ---------------------------------------------------------

        if not reasons:
            temp_desc = (
                f" at {round(temp)}°C"
                if temp is not None
                else ""
            )
            reasons.append(
                f"Clear route conditions with {cond.lower()} skies{temp_desc} and dry road surface."
            )

        return reasons

    # =============================================================
    # STATUS
    # =============================================================

    @staticmethod
    def _determine_status(
        *,
        safety_score: float | None,
        available_sources: list[str],
        confidence: float,
    ) -> str:
        """
        Operational status of the score.

        This does not classify a trip as safe/unsafe by itself.
        """

        if safety_score is None:
            return "score_unavailable"

        if not available_sources:
            return "score_unavailable"

        if confidence < 30.0:
            return "low_evidence"

        if confidence < 60.0:
            return "moderate_evidence"

        return "score_available"

    # =============================================================
    # LOOKUPS / HELPERS
    # =============================================================

    @staticmethod
    def _lookup_score(
        value: str,
        mapping: dict[str, float],
    ) -> float | None:
        """
        Case-insensitive score lookup.
        """

        normalized = (
            value.strip()
            .casefold()
        )

        return mapping.get(
            normalized
        )

    @staticmethod
    def _numeric_0_100(
        value: Any,
    ) -> float | None:
        """
        Return a numeric value only when it is explicitly within
        the 0-100 range.
        """

        if not isinstance(
            value,
            (int, float),
        ):
            return None

        numeric = float(value)

        if not 0.0 <= numeric <= 100.0:
            return None

        return numeric

    @staticmethod
    def _safety_level_to_score(
        value: Any,
    ) -> float | None:
        """
        Convert an explicitly named safety level into a score.

        These are configurable baseline mappings.
        """

        if not isinstance(
            value,
            str,
        ):
            return None

        mapping = {
            "very safe": 95.0,
            "safe": 85.0,
            "moderate": 65.0,
            "unsafe": 35.0,
            "very unsafe": 15.0,
        }

        return mapping.get(
            value.strip().casefold()
        )

    @staticmethod
    def _risk_level_to_score(
        value: Any,
    ) -> float | None:
        """
        Convert an explicitly named risk level into a 0-100
        risk score.

        Higher risk = lower safety.
        """

        if not isinstance(
            value,
            str,
        ):
            return None

        mapping = {
            "very low": 5.0,
            "low": 20.0,
            "moderate": 50.0,
            "high": 75.0,
            "very high": 95.0,
            "critical": 100.0,
        }

        return mapping.get(
            value.strip().casefold()
        )

    @staticmethod
    def _average(
        values: list[float],
    ) -> float:
        """
        Calculate a bounded arithmetic mean.
        """

        if not values:
            return 0.0

        return round(
            max(
                0.0,
                min(
                    100.0,
                    sum(values)
                    / len(values),
                ),
            ),
            2,
        )


# Shared service instance.
safety_score_service = SafetyScoreService()