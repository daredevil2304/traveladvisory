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

7. For real-time traveler traffic, Google Maps has dominant 80% weightage while community traveler reports have secondary 20% weightage. Always prioritize Google Maps telemetry for highway speeds and delays unless an explicit roadblock hazard is flagged.

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
    Write clean, readable sentences without asterisks, hashes, and code tags.

16. Always refer to real geographical town names (such as Mumbai, Panvel,
    Khalapur, Khopoli, Khandala / Bhor Ghat, Lonavala, Kamshet, Pune).
    Never output technical segment codes like R1, R2, R3, R4, R5, R6, R7.
    Always describe the corridor stretch using town names.

17. When explaining differences between Traveler and Planner scores:
    Explain that the Live Traveler score factors in real-time Google Maps road congestion (30% weight) and live community reports along the corridor right now. The Planner score is an advance forecast based on OpenWeather atmospheric conditions, Sahyadri mountain terrain geometry, and historical accident risk models, assuming typical free-flowing conditions without real-time congestion.

18. CRITICAL SAFETY SCORE ACCURACY:
    Always quote the exact integer safety scores provided in the backend context (e.g. 91/100, 92/100, 99/100).
    Never invent scores, never use different numbers, and never use decimal values (such as 97.8 or 97.2).
    If asked which section needs the most attention or care, always cite the exact segment identified in the context as having the lowest safety score, along with its exact score.
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

        analysis_data = trip.analysis_data
        if not analysis_data or not isinstance(analysis_data, dict):
            analysis = trip_analysis_service.analyze_trip(
                db=db,
                trip_id=trip_id,
            )
            analysis_data = analysis.to_dict()
            trip.analysis_data = analysis_data
            try:
                db.commit()
            except Exception:
                db.rollback()

        context = self._build_context(
            trip=trip,
            analysis=analysis_data,
        )

        prompt = self._build_prompt(
            message=message,
            context=context,
        )

        try:
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
        except Exception as exc:
            import logging
            logging.getLogger(__name__).warning(f"Groq provider fallback triggered: {exc}")
            fallback = self._generate_fallback_answer(
                trip=trip,
                analysis=analysis_data,
                message=message,
            )
            return ChatbotResponse(
                answer=fallback,
                provider="contextual_intelligence",
                model=None,
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
            ov_score_int = int(round(float(overall_score)))
            lines.append(
                f"Overall Route Safety Score: {ov_score_int}/100"
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
                
                from services.trip_analysis_service import SEGMENT_NAME_MAP

                if start and end:
                    region_name = f"Between {start} and {end}"
                else:
                    raw_reg = segment.get("region", "")
                    fallback_reg = raw_reg if raw_reg else "Corridor stretch"
                    region_name = SEGMENT_NAME_MAP.get(str(raw_reg).upper(), fallback_reg)

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

            # Find the lowest scoring segment(s) on the route
            min_score = float('inf')
            lowest_labels: list[str] = []
            from services.trip_analysis_service import SEGMENT_NAME_MAP
            for seg in segment_results:
                if not isinstance(seg, dict):
                    continue
                score_info = seg.get("safety_score_result") or {}
                raw_score = score_info.get("safety_score") or score_info.get("score") or seg.get("safety_score")
                if raw_score is not None:
                    s_int = int(round(float(raw_score)))
                    details = seg.get("segment_details") or {}
                    st = details.get("start")
                    en = details.get("end")
                    reg = seg.get("region", "")
                    lbl = f"{st} to {en}" if (st and en) else SEGMENT_NAME_MAP.get(str(reg).upper(), reg)
                    if s_int < min_score:
                        min_score = s_int
                        lowest_labels = [f"{lbl} ({s_int}/100)"]
                    elif s_int == min_score:
                        lowest_labels.append(f"{lbl} ({s_int}/100)")

            if lowest_labels and min_score < float('inf'):
                lines.append(f"Lowest scoring section on entire route: {', '.join(lowest_labels)}")

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
                label = f"{start} to {end}" if (start and end) else SEGMENT_NAME_MAP.get(str(reg).upper(), reg)

                score_info = seg.get("safety_score_result") or {}
                seg_score = score_info.get("safety_score") or score_info.get("score") or seg.get("safety_score")
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
                    seg_int = int(round(float(seg_score)))
                    lines.append(f"  Safety Score: {seg_int}/100")
                else:
                    lines.append("  Safety Score: unavailable")
                lines.append(f"  Live Weather: {', '.join(weather_desc)}")

                live_traffic = seg.get("live_traffic")
                if isinstance(live_traffic, dict) and live_traffic.get("status_label"):
                    delay_m = live_traffic.get("delay_minutes", 0)
                    delay_str = f"+{delay_m}m delay" if delay_m > 0 else "Free Flow"
                    lines.append(f"  Live Traffic: {live_traffic.get('status_label')} ({delay_str}, advised speed {live_traffic.get('speed_advice')})")

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

    @staticmethod
    def _generate_fallback_answer(
        trip: Trip,
        analysis: dict[str, Any],
        message: str,
    ) -> str:
        raw_score = analysis.get("overall_safety_score") or analysis.get("safety_score") or 80
        score = int(round(float(raw_score)))
        src = trip.source_name
        dst = trip.destination_name
        reasons = analysis.get("reasons") or []
        problematic = analysis.get("problematic_segments") or []
        precautions = analysis.get("precautions") or []
        segment_results = analysis.get("segment_results") or []
        dep_opt = analysis.get("departure_optimization") or {}

        msg_lower = message.lower()

        # 1. Weather / Rain / Fog / Visibility Queries
        if any(w in msg_lower for w in ["weather", "rain", "fog", "visibility", "temp", "temperature", "cloud", "monsoon"]):
            weather_findings = []
            for seg in segment_results:
                w_info = seg.get("weather_result") or {}
                if isinstance(w_info, dict) and w_info:
                    reg_name = (seg.get("segment_details") or {}).get("start", seg.get("region"))
                    cond = w_info.get("condition") or w_info.get("rain") or "Clear"
                    temp = w_info.get("temp") or w_info.get("temperature")
                    vis = w_info.get("visibility_km")
                    desc = f"{reg_name}: {cond}"
                    if temp is not None:
                        desc += f" at {round(float(temp))}°C"
                    if vis is not None:
                        desc += f", sightline {vis} km"
                    weather_findings.append(desc)
            if weather_findings:
                return f"Weather conditions along {src} to {dst}: " + "; ".join(weather_findings[:3]) + ". Maintain safe following distance on wet pavement."
            return f"Weather outlook between {src} and {dst} shows clear skies with standard atmospheric visibility across all expressway sections."

        # 2. Traffic / Congestion / Delay Queries
        if any(w in msg_lower for w in ["traffic", "jam", "congestion", "delay", "slow", "standstill", "blocked"]):
            traffic_delays = []
            total_delay = 0
            for seg in segment_results:
                t_info = seg.get("live_traffic") or {}
                if isinstance(t_info, dict):
                    d_min = t_info.get("delay_minutes", 0)
                    total_delay += d_min
                    if d_min >= 3:
                        reg_name = (seg.get("segment_details") or {}).get("start", seg.get("region"))
                        traffic_delays.append(f"{reg_name} (+{d_min}m slowdown)")
            if traffic_delays:
                return f"Live traffic delay on {src} to {dst}: Total corridor delay is approximately +{total_delay} minutes. Active slowdowns noted at: {', '.join(traffic_delays)}."
            return f"Corridor traffic between {src} and {dst} is fluid with free-flow speeds (85-100 km/h) and minimal delay (+{total_delay}m)."

        # 3. Hazard / Road Condition / Pothole / Landslide Queries
        if any(w in msg_lower for w in ["hazard", "landslide", "rockfall", "pothole", "accident", "road condition", "danger", "risk", "waterlog"]):
            hazards = [r for r in reasons if any(hz in str(r).lower() for hz in ["landslide", "rockfall", "waterlog", "pothole", "accident", "hazard", "congestion"])]
            if hazards:
                return f"Active road alerts on your route: {'; '.join(hazards[:3])}. Exercise heightened caution through these affected sectors."
            return f"No active structural hazards, landslides, or road closures reported on the {src} to {dst} expressway corridor."

        # 4. Departure Timing / Optimization Queries
        if any(w in msg_lower for w in ["leave", "depart", "when", "time", "wait", "now", "optimal", "timing"]):
            opt_summary = dep_opt.get("recommendation_summary")
            opt_score = dep_opt.get("optimal_safety_score")
            opt_time = dep_opt.get("optimal_departure_time_ist")
            if opt_summary:
                return f"Departure timing advisory: {opt_summary}. (Optimal score: {opt_score}/100 at {opt_time})."
            return f"Current travel conditions are favorable with a corridor Safety Score of {score}/100. Departing now or within the next 30 minutes offers optimal transit flow."

        # 5. Speed / Limit / Driving Advice
        if any(w in msg_lower for w in ["speed", "limit", "driving", "fast", "mph", "km/h", "kmph"]):
            if score < 75:
                return f"Due to current cautionary conditions (Safety Score {score}/100), maintain a moderated speed of 60-70 km/h on express stretches and 40 km/h on Ghat hairpin bends."
            return f"Posted speed limit is 100 km/h on expressway flats and 50 km/h through Bhor Ghat. Current road conditions support standard expressway cruising speeds."

        # 6. Specific Towns / Ghat Inquiry
        for town, reg in [("khandala", "R4"), ("lonavala", "R5"), ("khopoli", "R3"), ("panvel", "R1"), ("kamshet", "R6"), ("ghat", "R4"), ("bhor", "R4")]:
            if town in msg_lower:
                matching = [s for s in segment_results if s.get("region") == reg]
                if matching:
                    m = matching[0]
                    s_score = m.get("safety_score_result", {}).get("safety_score", score)
                    reasons_m = m.get("safety_score_result", {}).get("reasons", [])
                    r_str = f" Noteworthy conditions: {'; '.join(reasons_m[:2])}." if reasons_m else " Road is clear and stable."
                    return f"{town.capitalize()} section (Sector {reg}): Safety Score is {round(float(s_score))}/100.{r_str}"

        # 7. Safety Score & Reasons
        if any(w in msg_lower for w in ["score", "why", "low", "safe", "danger"]):
            if score >= 85:
                return (
                    f"Your journey from {src} to {dst} is safe to travel with an optimal Safety Score of {score}/100. "
                    f"The route has clear weather, smooth roads, and fluid traffic flow throughout the corridor."
                )
            ans = f"Your journey from {src} to {dst} has an overall Safety Score of {score}/100. "
            if reasons:
                ans += f"Key factors affecting the score: {'; '.join(str(r) for r in reasons[:2])}."
            else:
                ans += "Corridor road conditions are generally stable with standard expressway precautions."
            return ans

        # 8. Caution Sections
        if any(w in msg_lower for w in ["segment", "stretch", "where", "care", "attention", "caution"]):
            if problematic:
                names = []
                for p in problematic[:3]:
                    d = p.get("segment_details") or {}
                    s_val = p.get("safety_score")
                    s_str = f"{int(round(float(s_val)))}/100" if s_val is not None else "caution"
                    if d.get("start") and d.get("end"):
                        names.append(f"{d['start']} to {d['end']} (Safety Score: {s_str})")
                    else:
                        names.append(str(p.get("region", "Corridor section")))
                return f"Sections requiring caution along your route: {'; '.join(names)}."
            return f"All route sections between {src} and {dst} are clear and safe. There are no caution areas on your route."

        # 9. General Comprehensive Response Grounded in Trip Intelligence
        resp = f"Route analysis for {src} to {dst}: Corridor Safety Score is {score}/100. "
        if reasons:
            resp += f"Current observations: {'; '.join(str(r) for r in reasons[:2])}. "
        resp += "Drive carefully, maintain safe following distance, and observe expressway speed limits."
        return resp


chatbot_service = ChatbotService()