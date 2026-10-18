from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import Any

from services.route_segment_service import ROUTE_POINT_COORDINATES
from services.timezone_service import to_ist
from services.weather_service import weather_service


class DepartureOptimizerService:
    """
    Evaluates departure time windows (+/- 1 hour) around the user's selected
    planned departure time to proactively identify optimal travel windows
    with higher safety scores and reduced Ghat storm exposure.
    """

    OFFSETS_MINUTES = [-60, -30, 0, 30, 60]

    def optimize_departure_window(
        self,
        base_datetime: datetime,
        route_segments: list[str],
        current_safety_score: float | None = None,
    ) -> dict[str, Any]:
        """
        Evaluate alternative departure windows at -60m, -30m, +30m, +60m.
        Compares weather trends over the critical Western Ghats section (R4/R5).
        """
        ist_base = to_ist(base_datetime)
        curr_score = current_safety_score or 85.0

        # Focus weather check on the most vulnerable sector (Khopoli/Khandala R4)
        ghat_lat, ghat_lon = ROUTE_POINT_COORDINATES.get("Khopoli", (18.7877, 73.3438))

        alternatives: list[dict[str, Any]] = []
        best_offset = 0
        best_score = curr_score
        best_reason = "Current departure is within an optimal travel window."

        for offset in self.OFFSETS_MINUTES:
            slot_time = ist_base + timedelta(minutes=offset)
            time_label = slot_time.strftime("%I:%M %p")

            if offset == 0:
                alternatives.append({
                    "offset_minutes": 0,
                    "departure_time": slot_time.isoformat(),
                    "display_time": time_label,
                    "safety_score": round(curr_score, 1),
                    "is_current": True,
                    "condition": "Scheduled Departure",
                })
                continue

            try:
                # Query forecast for the alternative time
                w_data = weather_service.get_forecast_weather(
                    latitude=ghat_lat,
                    longitude=ghat_lon,
                    target_time=slot_time,
                    city_name="khandala",
                )

                # Score estimate based on forecasted conditions at slot
                score_mod = 0.0
                cond_desc = "Clear road conditions"

                if w_data.rainfall_mm and w_data.rainfall_mm > 4.0:
                    score_mod -= 12.0
                    cond_desc = "Heavy rain over Ghats"
                elif w_data.rainfall_mm and w_data.rainfall_mm > 0.5:
                    score_mod -= 6.0
                    cond_desc = "Light rain over Ghats"
                elif w_data.humidity_percent and w_data.humidity_percent > 92.0:
                    score_mod -= 4.0
                    cond_desc = "Dense mountain mist"
                else:
                    score_mod += 3.0
                    cond_desc = "Clear dry conditions"

                # Night driving adjustment
                if slot_time.hour >= 22 or slot_time.hour <= 5:
                    score_mod -= 4.0
                    cond_desc += " (Night)"

                est_score = round(max(30.0, min(100.0, curr_score + score_mod)), 1)

            except Exception:
                est_score = round(curr_score, 1)
                cond_desc = "Estimated forecast window"

            alternatives.append({
                "offset_minutes": offset,
                "departure_time": slot_time.isoformat(),
                "display_time": time_label,
                "safety_score": est_score,
                "is_current": False,
                "condition": cond_desc,
            })

            if est_score > best_score + 2.0:
                best_score = est_score
                best_offset = offset

        score_diff = round(best_score - curr_score, 1)
        best_slot_time = ist_base + timedelta(minutes=best_offset)
        best_slot_label = best_slot_time.strftime("%I:%M %p")

        if best_offset != 0 and score_diff >= 3.0:
            direction = "later" if best_offset > 0 else "earlier"
            recommendation = (
                f"Proactive Timing Advice: Departing at {best_slot_label} ({abs(best_offset)} mins {direction}) "
                f"increases route safety from {curr_score:.0f} to {best_score:.0f}/100 (+{score_diff:.0f} pts) "
                f"with clearer conditions through Bhor Ghat."
            )
            has_recommendation = True
        else:
            recommendation = (
                f"Selected departure at {ist_base.strftime('%I:%M %p')} is already in an optimal corridor window "
                f"with favorable safety margins ({curr_score:.0f}/100)."
            )
            has_recommendation = False

        return {
            "has_better_alternative": has_recommendation,
            "optimal_offset_minutes": best_offset,
            "optimal_departure_time": best_slot_time.isoformat(),
            "optimal_display_time": best_slot_label,
            "current_safety_score": round(curr_score, 1),
            "optimal_safety_score": round(best_score, 1),
            "score_improvement": score_diff,
            "recommendation_text": recommendation,
            "alternative_windows": alternatives,
        }


departure_optimizer_service = DepartureOptimizerService()
