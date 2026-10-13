from __future__ import annotations

from dataclasses import asdict, dataclass
import json
import re
from typing import Any

from services.llm_service import LLMService
from services.groq_provider import groq_provider


@dataclass(frozen=True)
class NormalizedObservation:
    """
    Standardized representation of a traveler's
    natural-language weather/road observation.

    Natural-language interpretation is performed by the LLM.
    This class only stores the validated structured result.
    """

    raw_text: str

    rain: str | None = None
    visibility: str | None = None
    fog: str | None = None
    unusual_conditions: str | None = None
    traffic: str | None = None

    location_mentioned: str | None = None

    confidence: float = 0.0

    needs_clarification: bool = False
    clarification_question: str | None = None

    extraction_method: str = "llm"

    def to_dict(self) -> dict:
        return asdict(self)


class ObservationNormalizer:
    """
    Converts a traveler's natural-language observation into
    a validated structured observation.

    Architecture:

        User message
             ↓
        LLM extraction
             ↓
        JSON parsing
             ↓
        Schema validation
             ↓
        NormalizedObservation

    The LLM is responsible for understanding natural language.

    This class does NOT maintain a phrase dictionary and does NOT
    attempt to understand arbitrary English/Hinglish/Hindi itself.

    A minimal fallback is used only when the LLM cannot provide
    a valid structured response.
    """

    # ------------------------------------------------------------------
    # Controlled output schema
    # ------------------------------------------------------------------

    RAIN_CATEGORIES = {
        "very_heavy",
        "heavy",
        "moderate",
        "light",
        "no_rain",
    }

    VISIBILITY_CATEGORIES = {
        "very_poor",
        "poor",
        "moderately_reduced",
        "slightly_reduced",
        "clear",
        "very_clear",
    }

    FOG_CATEGORIES = {
        "very_dense",
        "dense",
        "moderate",
        "light",
        "none",
    }

    UNUSUAL_CONDITION_CATEGORIES = {
        "fallen_tree",
        "landslide_rockfall",
        "flooding",
        "debris_on_road",
        "accident_incident",
        "road_damage",
        "construction_activity",
        "road_closure",
        "slippery_road",
        "other",
    }

    TRAFFIC_CATEGORIES = {
        "standstill",
        "very_heavy",
        "heavy",
        "moderate",
        "light",
        "free_flow",
    }

    # ------------------------------------------------------------------
    # LLM instruction
    # ------------------------------------------------------------------

    SYSTEM_PROMPT = """
You are the natural-language observation extraction component of a
Mumbai-Pune travel intelligence system.

Your ONLY task is to understand the user's message and convert the
information explicitly stated or clearly implied by the user into a
structured JSON observation.

You are NOT responsible for:
- calculating a safety score
- deciding whether the journey is safe
- predicting weather
- inventing missing information
- generating travel recommendations

Understand natural conversational language including:

- English
- Hinglish
- Hindi written using English letters
- informal speech
- spelling variations
- grammatical errors
- abbreviations
- conversational expressions
- mixed English/Hindi sentences

Do NOT depend on exact phrases.

Interpret the meaning of the complete sentence and map it to the
appropriate controlled category.

Return ONLY valid JSON.

Use exactly this structure:

{
  "observations": {
    "rain": null,
    "visibility": null,
    "fog": null,
    "unusual_conditions": null,
    "traffic": null
  },
  "location_mentioned": null,
  "confidence": 0.0,
  "needs_clarification": false,
  "clarification_question": null
}

Allowed rain values:

- very_heavy
- heavy
- moderate
- light
- no_rain

Allowed visibility values:

- very_poor
- poor
- moderately_reduced
- slightly_reduced
- clear
- very_clear

Allowed fog values:

- very_dense
- dense
- moderate
- light
- none

Allowed unusual_conditions values:

- fallen_tree
- landslide_rockfall
- flooding
- debris_on_road
- accident_incident
- road_damage
- construction_activity
- road_closure
- slippery_road
- other

Allowed traffic values:

- standstill
- very_heavy
- heavy
- moderate
- light
- free_flow

If a category is not mentioned, return null.

Interpret severity according to meaning, not exact wording.

Examples of semantic interpretation:

A statement describing extremely intense rainfall should map to:
rain = "very_heavy"

A statement describing strong/heavy rainfall should map to:
rain = "heavy"

A statement describing light rainfall or drizzle should map to:
rain = "light"

A statement describing extremely poor ability to see should map to:
visibility = "very_poor"

A statement describing significantly reduced ability to see should map to:
visibility = "poor"

A statement describing somewhat reduced visibility should map to:
visibility = "moderately_reduced" or "slightly_reduced" depending on severity.

A statement describing clear visibility should map to:
visibility = "clear" or "very_clear" depending on the wording.

A statement describing extremely dense fog should map to:
fog = "very_dense"

A statement describing thick/heavy/dense fog should map to:
fog = "dense"

A statement describing ordinary fog without strong severity should map to:
fog = "moderate"

A statement describing light mist/fog should map to:
fog = "light"

A statement explicitly saying there is no fog should map to:
fog = "none"

A statement describing fallen trees blocking or affecting the road should map to:
unusual_conditions = "fallen_tree"

A statement describing rocks, stones, boulders, or material falling onto
the road from a hill, mountain, ghat, or slope should map to:
unusual_conditions = "landslide_rockfall"

A statement describing accumulated water or flooding on the road should map to:
unusual_conditions = "flooding"

A statement describing loose material/debris on the road should map to:
unusual_conditions = "debris_on_road"

A statement describing an accident, crash, collision, or road incident should map to:
unusual_conditions = "accident_incident"

A statement describing potholes or physical damage to the road should map to:
unusual_conditions = "road_damage"

A statement describing construction work affecting the road should map to:
unusual_conditions = "construction_activity"

A statement describing a road/highway being closed should map to:
unusual_conditions = "road_closure"

A statement describing the road surface as slippery or difficult to maintain
traction on should map to:
unusual_conditions = "slippery_road"

If an unusual road condition is clearly reported but does not match the
specific categories above, use:
unusual_conditions = "other"

Traffic categories describe the current traffic condition only.

If traffic is completely stopped:
traffic = "standstill"

If traffic is extremely congested:
traffic = "very_heavy"

If traffic is heavily congested:
traffic = "heavy"

If traffic is moderately congested:
traffic = "moderate"

If traffic is light:
traffic = "light"

If traffic is moving freely:
traffic = "free_flow"

Do not infer traffic merely because weather is bad.

Do not infer a condition that the user did not communicate.

Do not make a condition more severe merely because another condition is
severe.

For example, if the user communicates heavy rain, dense fog, and poor
visibility, preserve those independently:

rain = "heavy"
fog = "dense"
visibility = "poor"

If the user's statement is too vague to determine the reported condition,
set:

"needs_clarification": true

and provide a short clarification question.

For example, a message equivalent in meaning to:
"Something is wrong on the road"

does not provide enough information to determine the specific condition.

If the user mentions a location, extract the location name.

Do not invent a location.

Confidence must be a number between 0 and 1.

Important:

Do NOT copy or memorize example sentences.

Generalize from their meaning and understand unseen natural-language
variations.
"""

    def __init__(
        self,
        llm_service_instance: LLMService | None = None,
    ) -> None:
        self._llm_service = llm_service_instance

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    def normalize(self, text: str) -> NormalizedObservation:
        """
        Normalize a traveler's observation.

        Primary path:
            LLM → structured JSON → validation

        Failure path:
            Minimal empty fallback

        The fallback intentionally does not perform natural-language
        phrase matching.
        """

        if not isinstance(text, str):
            raise ValueError("Observation must be a string.")

        raw_text = text.strip()

        if not raw_text:
            raise ValueError("Observation cannot be empty.")

        try:
            return self._normalize_with_llm(raw_text)
        except Exception:
            return self._normalize_with_fallback(raw_text)

    # ------------------------------------------------------------------
    # LLM path
    # ------------------------------------------------------------------

    def _normalize_with_llm(
        self,
        raw_text: str,
    ) -> NormalizedObservation:

        service = self._get_llm_service()

        response = service.generate(
            prompt=(
                "Extract the structured travel observation from the "
                "following user message.\n\n"
                f"User message:\n{raw_text}"
            ),
            system_prompt=self.SYSTEM_PROMPT,
        )

        data = self._parse_json_response(response.content)

        return self._build_from_llm_data(
            raw_text=raw_text,
            data=data,
        )

    def _get_llm_service(self) -> LLMService:
        if self._llm_service is not None:
            return self._llm_service

        return LLMService(
            provider=openrouter_provider,
        )

    # ------------------------------------------------------------------
    # LLM response validation
    # ------------------------------------------------------------------

    def _build_from_llm_data(
        self,
        raw_text: str,
        data: dict[str, Any],
    ) -> NormalizedObservation:

        observations = data.get("observations")

        if not isinstance(observations, dict):
            raise ValueError(
                "LLM response does not contain a valid observations object."
            )

        rain = self._validate_category(
            observations.get("rain"),
            self.RAIN_CATEGORIES,
        )

        visibility = self._validate_category(
            observations.get("visibility"),
            self.VISIBILITY_CATEGORIES,
        )

        fog = self._validate_category(
            observations.get("fog"),
            self.FOG_CATEGORIES,
        )

        unusual_conditions = self._validate_category(
            observations.get("unusual_conditions"),
            self.UNUSUAL_CONDITION_CATEGORIES,
        )

        traffic = self._validate_category(
            observations.get("traffic"),
            self.TRAFFIC_CATEGORIES,
        )

        location = data.get("location_mentioned")

        if location is not None:

            if not isinstance(location, str):
                location = None

            else:
                location = location.strip() or None

        confidence = data.get("confidence", 0.0)

        try:
            confidence = float(confidence)

        except (TypeError, ValueError):
            confidence = 0.0

        confidence = max(
            0.0,
            min(1.0, confidence),
        )

        needs_clarification = bool(
            data.get(
                "needs_clarification",
                False,
            )
        )

        clarification_question = data.get(
            "clarification_question"
        )

        if clarification_question is not None:

            if not isinstance(
                clarification_question,
                str,
            ):
                clarification_question = None

            else:
                clarification_question = (
                    clarification_question.strip()
                    or None
                )

        # Protect against contradictory LLM output.
        if needs_clarification and not clarification_question:
            clarification_question = (
                "Could you describe the weather or road condition "
                "you are experiencing?"
            )

        return NormalizedObservation(
            raw_text=raw_text,
            rain=rain,
            visibility=visibility,
            fog=fog,
            unusual_conditions=unusual_conditions,
            traffic=traffic,
            location_mentioned=location,
            confidence=confidence,
            needs_clarification=needs_clarification,
            clarification_question=clarification_question,
            extraction_method="llm",
        )

    # ------------------------------------------------------------------
    # Controlled vocabulary validation
    # ------------------------------------------------------------------

    @staticmethod
    def _validate_category(
        value: Any,
        allowed: set[str],
    ) -> str | None:

        if value is None:
            return None

        if not isinstance(value, str):
            return None

        value = value.strip().lower()

        if not value:
            return None

        if value not in allowed:
            return None

        return value

    # ------------------------------------------------------------------
    # JSON parsing
    # ------------------------------------------------------------------

    @staticmethod
    def _parse_json_response(
        content: str,
    ) -> dict[str, Any]:

        if not isinstance(content, str):
            raise ValueError(
                "LLM response must be text."
            )

        cleaned = content.strip()

        if not cleaned:
            raise ValueError(
                "LLM returned an empty response."
            )

        # Handle accidental Markdown code fences.
        if cleaned.startswith("```"):

            cleaned = re.sub(
                r"^```(?:json)?\s*",
                "",
                cleaned,
                flags=re.IGNORECASE,
            )

            cleaned = re.sub(
                r"\s*```$",
                "",
                cleaned,
            ).strip()

        try:
            data = json.loads(cleaned)

        except json.JSONDecodeError as exc:
            raise ValueError(
                "LLM response was not valid JSON."
            ) from exc

        if not isinstance(data, dict):
            raise ValueError(
                "LLM JSON response must be an object."
            )

        return data

    # ------------------------------------------------------------------
    # Minimal failure fallback
    # ------------------------------------------------------------------

    @staticmethod
    def _normalize_with_fallback(
        raw_text: str,
    ) -> NormalizedObservation:
        """
        Failure-safe fallback.

        IMPORTANT:
        This method deliberately does NOT attempt natural-language
        interpretation.

        We would rather return an unknown observation than incorrectly
        classify a traveler's report using brittle phrase matching.
        """

        return NormalizedObservation(
            raw_text=raw_text,
            rain=None,
            visibility=None,
            fog=None,
            unusual_conditions=None,
            traffic=None,
            location_mentioned=None,
            confidence=0.0,
            needs_clarification=True,
            clarification_question=(
                "I couldn't reliably understand the reported condition. "
                "Could you describe what you are experiencing on the road?"
            ),
            extraction_method="fallback",
        )


# ----------------------------------------------------------------------
# Shared normalizer instance
# ----------------------------------------------------------------------

observation_normalizer = ObservationNormalizer(
    llm_service_instance=LLMService(
        provider=groq_provider,
    )
)