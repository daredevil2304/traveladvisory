from __future__ import annotations

from dataclasses import dataclass
from typing import Any

from sqlalchemy.orm import Session

from models.trip import Trip
from services.groq_provider import groq_provider
from services.trip_analysis_service import trip_analysis_service


@dataclass(frozen=True)
class ChatbotResponse:
    answer: str
    provider: str
    model: str | None
    trip_id: int


class ChatbotService:
    """
    Grounded conversational layer for the travel advisor.

    The chatbot does NOT calculate Safety Scores.
    It explains and discusses intelligence already produced
    by the deterministic travel-intelligence pipeline.
    """

    _SYSTEM_PROMPT = """
You are the conversational assistant for a Mumbai-Pune Travel
Intelligence application.

Your job is to explain and discuss the travel intelligence supplied
by the backend.

IMPORTANT RULES:

1. The backend Safety Score is authoritative.
   Never calculate, replace, estimate, or invent a new Safety Score.

2. Use only the supplied trip and analysis context for journey-specific
   factual claims.

3. Never invent weather conditions, route segments, locations,
   traveler reports, ML predictions, confidence values, or sources.

4. If the supplied context does not contain an answer, clearly say
   that the available intelligence does not provide that information.

5. Explain technical results in simple, natural language.

6. The analysis evaluates route segments individually. When discussing
   a location, identify the relevant route segment when available.

7. Traffic may appear as traveler evidence, but traffic is NOT part of
   the Safety Score unless the supplied backend context explicitly says
   otherwise.

8. Do not claim that an alternate route exists unless the supplied
   context explicitly contains an alternate route.

9. Do not claim that a future weather condition is known unless the
   supplied context contains that forecast/prediction.

10. Do not expose API keys, internal credentials, or implementation
    secrets.

11. If the user asks "why", explain the actual evidence and reasons
    behind the existing analysis.

12. If the user asks about precautions, provide practical precautions
    grounded in the conditions present in the supplied analysis.

13. Be concise but useful. Prefer short paragraphs and bullets when
    appropriate.

14. This is a travel-information assistant, not a replacement for
    the user's own judgment or official road authorities.

15. Do NOT use markdown bold asterisks (such as **) anywhere in your output.
    Write clean, readable sentences without asterisks, hashes, or code tags.
""".strip()

    def answer(
        self,
        db: Session,
        trip_id: int,
        message: str,
    ) -> ChatbotResponse:
        if not isinstance(message, str) or not message.strip():
            raise ValueError("Message cannot be empty.")

        trip = (
            db.query(Trip)
            .filter(Trip.id == trip_id)
            .first()
        )

        if trip is None:
            raise ValueError(
                f"Trip with id {trip_id} was not found."
            )

        analysis = trip_analysis_service.analyze_trip(
            db=db,
            trip_id=trip_id,
        )

        analysis_data = analysis.to_dict()

        context = self._build_context(
            trip=trip,
            analysis=analysis_data,
        )

        prompt = self._build_prompt(
            message=message,
            context=context,
        )

        response = groq_provider.generate(
            prompt=prompt,
            system_prompt=self._SYSTEM_PROMPT,
        )

        return ChatbotResponse(
            answer=response.content,
            provider=response.provider,
            model=response.model,
            trip_id=trip_id,
        )

    @staticmethod
    def _build_context(
        trip: Trip,
        analysis: dict[str, Any],
    ) -> str:
        """
        Build a compact, explicit context block for Groq.

        The model receives backend-generated facts only.
        Only problematic segments are included to avoid mentioning safe regions.
        """

        lines: list[str] = []

        lines.append("=== TRIP ===")
        lines.append(f"Trip ID: {trip.id}")
        lines.append(f"Role: {trip.role}")
        lines.append(f"Source: {trip.source_name}")
        lines.append(f"Destination: {trip.destination_name}")
        lines.append(
            f"Travel datetime: {trip.travel_datetime.isoformat()}"
        )

        lines.append("")
        lines.append("=== TRIP ANALYSIS ===")

        lines.append(
            f"Status: {analysis.get('status')}"
        )

        overall_score = analysis.get(
            "overall_safety_score"
        )

        overall_confidence = analysis.get(
            "overall_confidence"
        )

        if overall_score is not None:
            lines.append(
                f"Overall Safety Score: {overall_score}/100"
            )
        else:
            lines.append(
                "Overall Safety Score: unavailable"
            )

        if overall_confidence is not None:
            lines.append(
                f"Overall evidence confidence: "
                f"{overall_confidence}%"
            )
        else:
            lines.append(
                "Overall evidence confidence: unavailable"
            )

        reasons = analysis.get("reasons")

        if isinstance(reasons, list) and reasons:
            lines.append("")
            lines.append("Overall reasons:")

            for reason in reasons[:10]:
                lines.append(f"- {reason}")

        available_sources = analysis.get(
            "available_intelligence_sources"
        )

        missing_sources = analysis.get(
            "missing_intelligence_sources"
        )

        if isinstance(available_sources, list):
            lines.append("")
            lines.append(
                "Available intelligence sources:"
            )

            for source in available_sources:
                lines.append(f"- {source}")

        if isinstance(missing_sources, list):
            lines.append("")
            lines.append(
                "Missing or unavailable sources:"
            )

            for source in missing_sources:
                lines.append(f"- {source}")

        problematic = analysis.get(
            "problematic_segments"
        )

        if isinstance(problematic, list) and problematic:
            lines.append("")
            lines.append(
                "=== PROBLEMATIC SEGMENTS ==="
            )

            for segment in problematic[:10]:
                if not isinstance(segment, dict):
                    continue

                details = segment.get("segment_details", {})
                
                start = details.get("start")
                end = details.get("end")
                
                if start and end:
                    region_name = f"Between {start} and {end}"
                else:
                    region_name = segment.get("region", "Unknown Region")

                score = segment.get(
                    "safety_score"
                )

                segment_reasons = segment.get(
                    "reasons"
                )

                text = f"- {region_name}"

                if score is not None:
                    text += (
                        f": score {score}/100"
                    )

                if (
                    isinstance(
                        segment_reasons,
                        list,
                    )
                    and segment_reasons
                ):
                    text += (
                        "; "
                        + "; ".join(
                            str(reason)
                            for reason
                            in segment_reasons[:4]
                        )
                    )

                lines.append(text)

        segment_results = analysis.get("segment_results")
        if isinstance(segment_results, list) and segment_results:
            lines.append("")
            lines.append("=== ROUTE SEGMENTS & WEATHER OBSERVATIONS ===")
            for seg in segment_results:
                if not isinstance(seg, dict):
                    continue
                details = seg.get("segment_details") or {}
                start = details.get("start")
                end = details.get("end")
                reg = seg.get("region", "")
                if (not start or not end) and reg:
                    try:
                        from services.route_segment_service import get_segment_details
                        rs = get_segment_details(reg)
                        start = rs.start
                        end = rs.end
                    except Exception:
                        pass
                label = f"{start} to {end} ({reg})" if (start and end) else reg

                score_info = seg.get("safety_score_result") or {}
                seg_score = score_info.get("score")
                seg_reasons = score_info.get("reasons") or []

                weather = seg.get("weather_result") or {}
                cond = weather.get("weather_condition") or "Clear / Normal"
                temp = weather.get("temperature_c")
                rain = weather.get("rainfall_mm")
                vis = weather.get("visibility_km")
                humid = weather.get("humidity_percent")
                wind = weather.get("wind_speed_kmh")

                weather_desc: list[str] = [f"Condition: {cond}"]
                if temp is not None:
                    weather_desc.append(f"Temperature: {temp}°C")
                if rain is not None:
                    weather_desc.append(f"Rainfall: {rain} mm/h")
                if vis is not None:
                    weather_desc.append(f"Visibility: {vis} km")
                if humid is not None:
                    weather_desc.append(f"Humidity: {humid}%")
                if wind is not None:
                    weather_desc.append(f"Wind: {wind} km/h")

                lines.append(f"- Segment {label}:")
                if seg_score is not None:
                    lines.append(f"  Safety Score: {seg_score}/100")
                else:
                    lines.append("  Safety Score: unavailable")
                lines.append(f"  Live Weather: {', '.join(weather_desc)}")
                if seg_reasons:
                    lines.append(f"  Advisories: {'; '.join(str(r) for r in seg_reasons[:3])}")

        return "\n".join(lines)

    @staticmethod
    def _build_prompt(
        message: str,
        context: str,
    ) -> str:
        return f"""
The user is asking a question about an already-created travel
analysis.

Answer the user's question using the backend context below.

=== USER QUESTION ===
{message.strip()}

=== BACKEND CONTEXT ===
{context}

=== RESPONSE REQUIREMENTS ===
- Answer the user's actual question directly.
- Use the backend context as the source of truth.
- Do not invent missing facts.
- Do not recalculate the Safety Score.
- If the user asks why the score is what it is, explain the
  supplied reasons and evidence.
- If the user asks about a particular segment, use the segment
  information supplied above.
- If the user asks for something not present in the context,
  explicitly say that the current analysis does not contain that
  information.
""".strip()


chatbot_service = ChatbotService()