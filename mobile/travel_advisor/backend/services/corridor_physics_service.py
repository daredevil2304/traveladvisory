from __future__ import annotations

import math
from typing import Any


class CorridorPhysicsService:
    """
    Computes physics-based dynamic safe speed limit advisories,
    corridor elevation profile data, and emergency rescue directory
    tailored specifically for the Mumbai-Pune Expressway (NH-48).
    """

    # Statutory speed limits (dry road standard, km/h)
    STATUTORY_SPEED_LIMITS: dict[str, int] = {
        "R1": 80,   # Mumbai to Panvel (Urban expressway corridor)
        "R2": 100,  # Panvel to Khalapur (Expressway straight)
        "R3": 100,  # Khalapur to Khopoli (Expressway transition)
        "R4": 50,   # Khopoli to Khandala (Steep Bhor Ghat hairpins)
        "R5": 50,   # Khandala to Lonavala (Ghat crest & curves)
        "R6": 100,  # Lonavala to Talegaon (Plateau expressway)
        "R7": 80,   # Talegaon to Pune (Dehu road bypass)
    }

    # Terrain elevation along the Mumbai-Pune Expressway (km from Mumbai, elevation in meters)
    CORRIDOR_ELEVATION_PROFILE: list[dict[str, Any]] = [
        {"name": "Sion (Mumbai)", "km": 0, "elevation_m": 8, "region": "R1", "type": "origin"},
        {"name": "Vashi Bridge", "km": 15, "elevation_m": 10, "region": "R1", "type": "transit"},
        {"name": "Panvel", "km": 32, "elevation_m": 14, "region": "R2", "type": "waypoint"},
        {"name": "Khalapur Toll", "km": 58, "elevation_m": 48, "region": "R3", "type": "toll_plaza"},
        {"name": "Khopoli (Ghat Base)", "km": 71, "elevation_m": 72, "region": "R4", "type": "ghat_entry"},
        {"name": "Khandala Hairpins", "km": 81, "elevation_m": 550, "region": "R4", "type": "mountain_pass"},
        {"name": "Lonavala Crest", "km": 88, "elevation_m": 624, "region": "R5", "type": "peak_elevation"},
        {"name": "Kamshet Valley", "km": 104, "elevation_m": 590, "region": "R6", "type": "waypoint"},
        {"name": "Talegaon Toll", "km": 118, "elevation_m": 582, "region": "R6", "type": "toll_plaza"},
        {"name": "Somatne / Dehu", "km": 130, "elevation_m": 575, "region": "R7", "type": "waypoint"},
        {"name": "Pune (Shivajinagar)", "km": 148, "elevation_m": 560, "region": "R7", "type": "destination"},
    ]

    # Official Expressway Emergency Contacts & Rescue Hubs
    EMERGENCY_DIRECTORY: dict[str, Any] = {
        "emergency_contacts": [
            {
                "label": "IRB Expressway Emergency Control Room",
                "phone": "9822498224",
                "display": "98224 98224",
                "description": "24x7 Ambulance, Towing Crane & Patrol SOS",
                "priority": "HIGH",
            },
            {
                "label": "National Highway Patrol (MSRDC)",
                "phone": "1033",
                "display": "1033",
                "description": "Toll-free Expressway Emergency Helpline",
                "priority": "HIGH",
            },
            {
                "label": "Maharashtra Highway Police Control",
                "phone": "02025651515",
                "display": "020-25651515",
                "description": "State Highway Police Headquarters",
                "priority": "STANDARD",
            },
        ],
        "trauma_centers": [
            {
                "name": "MGM Medical College & Hospital",
                "location": "Kamothe / Panvel",
                "phone": "02227437900",
                "km_marker": "km 34",
                "specialty": "Level 1 Trauma Care",
            },
            {
                "name": "Jakhotia Trauma Care Hospital",
                "location": "Khopoli Phata",
                "phone": "02192263300",
                "km_marker": "km 70",
                "specialty": "Ghat Base Emergency Care",
            },
            {
                "name": "Sanjeevani Critical Care Hospital",
                "location": "Lonavala",
                "phone": "02114273545",
                "km_marker": "km 88",
                "specialty": "Mountain Crest Emergency",
            },
            {
                "name": "Lokmanya Trauma & Specialty Hospital",
                "location": "Nigdi / Pune",
                "phone": "02030717500",
                "km_marker": "km 138",
                "specialty": "Advanced Neuro & Ortho Trauma",
            },
        ],
        "authorized_rest_plazas": [
            {
                "name": "Khalapur Food Mall",
                "bound": "Pune-bound",
                "km_marker": "km 38",
                "amenities": ["Fuel / EV Fast Chargers", "Restrooms", "Food Court", "First Aid"],
            },
            {
                "name": "Ozarde Food Plaza",
                "bound": "Mumbai-bound",
                "km_marker": "km 78",
                "amenities": ["Fuel Station", "Vehicle Repair / Tire Care", "Food Court", "Restrooms"],
            },
        ],
    }

    def compute_safe_speed(
        self,
        region: str,
        weather_data: dict[str, Any] | None = None,
        safety_score: float | None = None,
        is_night: bool = False,
    ) -> dict[str, Any]:
        """
        Calculate dynamic safe speed advisory using road friction physics:
        d_brake = v^2 / [2 * g * (mu * cos(theta) - sin(theta))]

        Friction (mu):
          - Dry roads: ~0.80
          - Drizzle / damp: ~0.55
          - Moderate rain: ~0.40
          - Heavy rain / standing water: ~0.25 (high skidding danger)
        """
        reg = region.upper()
        statutory = self.STATUTORY_SPEED_LIMITS.get(reg, 80)
        is_ghat = reg in ("R4", "R5")

        raw_rain = (
            (weather_data.get("rain_condition") or weather_data.get("rain") or "")
        ).lower().strip() if weather_data else ""
        rain_mm = weather_data.get("rainfall_mm") if weather_data else None
        vis_km = weather_data.get("visibility_km") if weather_data else None
        fog_cond = (
            (weather_data.get("fog_condition") or weather_data.get("fog") or "")
        ).lower().strip() if weather_data else ""

        # Strictly verify genuine rain conditions (avoid false triggers on "no rain", "none", etc.)
        is_real_rain = False
        if raw_rain and raw_rain not in ("no rain", "none", "clear", "nil", "0", "false"):
            if any(w in raw_rain for w in ("heavy", "moderate", "drizzle", "shower", "thunderstorm", "monsoon")):
                is_real_rain = True
            elif "rain" in raw_rain and "no rain" not in raw_rain:
                is_real_rain = True

        if rain_mm is not None and rain_mm > 0.0:
            is_real_rain = True

        reduction_kmh = 0
        reasons: list[str] = []

        # 1. Road Surface Friction Degradation
        if is_real_rain:
            if "heavy" in raw_rain or (rain_mm is not None and rain_mm >= 15.0):
                reduction_kmh += int(statutory * 0.35)  # -35%
                reasons.append("Heavy rain: Standing water and high skidding risk. Drive slowly.")
            elif "moderate" in raw_rain or (rain_mm is not None and rain_mm >= 3.0):
                reduction_kmh += int(statutory * 0.20)  # -20%
                reasons.append("Wet road surface from rain: Reduced tire grip. Keep safe following distance.")
            else:
                reduction_kmh += int(statutory * 0.10)  # -10%
                reasons.append("Damp road surface from light rain: Drive with care.")

        # 2. Visibility / Fog Constraints
        if (vis_km is not None and vis_km < 1.0) or ("dense" in fog_cond):
            reduction_kmh += int(statutory * 0.30)
            reasons.append("Dense fog (<1 km visibility): Turn on fog lamps and reduce speed.")
        elif (vis_km is not None and vis_km < 3.0) or ("mist" in fog_cond):
            reduction_kmh += int(statutory * 0.15)
            reasons.append("Morning mist: Reduced sight distance. Use low-beam headlights.")

        # 3. Mountain Incline & Hairpin Gradient (Ghats)
        if is_ghat:
            if is_real_rain:
                reduction_kmh += 10
                reasons.append("Steep mountain descent with wet roads: Use lower gears to avoid brake fading.")
            elif not is_night and reduction_kmh == 0:
                reasons.append("Mountain pass: Maintain steady 50 km/h speed around sharp curves.")

        # 4. Night Driving Adjustment (Darkness & Low Lighting)
        if is_night:
            if is_ghat:
                reduction_kmh += 10
                reasons.append("Night driving in Ghats: Poor lighting and sharp turns. Drive under 40 km/h.")
            elif statutory >= 80:
                reduction_kmh += 10
                reasons.append("Night driving: Darkness on unlit stretches. Maintain extra following distance.")

        recommended = max(35 if is_ghat else 50, statutory - reduction_kmh)

        status = "NORMAL"
        if recommended <= statutory - 20 or (is_ghat and recommended <= 35):
            status = "CRITICAL_CAUTION"
        elif recommended < statutory:
            status = "ADVISORY_REDUCED"

        # Provide a clean, natural reason when highway is clear and conditions are normal
        final_reasons = reasons if reasons else ["Clear weather and dry, smooth roads. Normal cruising speed recommended."]

        return {
            "statutory_speed_kmh": statutory,
            "recommended_safe_speed_kmh": recommended,
            "speed_reduction_kmh": statutory - recommended,
            "status": status,
            "is_ghat_section": is_ghat,
            "advisory_reasons": final_reasons,
        }

    def get_elevation_profile(self) -> list[dict[str, Any]]:
        """Return cross-section elevation data points along the corridor."""
        return self.CORRIDOR_ELEVATION_PROFILE

    def get_emergency_directory(self) -> dict[str, Any]:
        """Return the official emergency rescue contacts and trauma centers."""
        return self.EMERGENCY_DIRECTORY


corridor_physics_service = CorridorPhysicsService()
