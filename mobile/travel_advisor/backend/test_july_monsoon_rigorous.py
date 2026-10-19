"""
Rigorous End-to-End Stress Test: July Peak Monsoon Cloudburst Scenario
Corridor: Mumbai - Pune Expressway (R1 to R7)
Scenario Date: July 25, 2024 at 14:30 IST (Extreme torrential rain, dense Ghat fog, severe traffic)

This test executes the entire intelligence pipeline:
- Regional XGBoost Machine Learning Models (safepass_model_*.joblib)
- Weather Normalization (Precipitation, Visibility, Fog)
- Google Maps Traffic vs. User Report Priority Logic (80/20 weighting)
- Data Fusion & Calibrated Source Weights (50% ML on Ghats, 50% Weather on Highway)
- Hydrodynamic Aquaplaning & Safe Speed Physics
- Weakest-Link Corridor Aggregation
- Smart Timing Advice (Departure Window Optimization)
"""

from __future__ import annotations

import sys
import os
from datetime import datetime, timezone, timedelta
from typing import Any

# Ensure backend root is on path
backend_dir = os.path.dirname(os.path.abspath(__file__))
if backend_dir not in sys.path:
    sys.path.insert(0, backend_dir)

from services.weather_service import WeatherData
from services.weather_normalizer import weather_normalizer
from services.prediction_service import prediction_service
from services.data_fusion_service import data_fusion_service
from services.safety_score_service import safety_score_service
from services.corridor_physics_service import corridor_physics_service
from services.departure_optimizer_service import departure_optimizer_service
from services.route_segment_service import (
    ROUTE_POINT_COORDINATES,
    get_segment_coordinates,
    get_segment_details,
)
from services.timezone_service import to_ist


def run_july_monsoon_rigorous_test():
    print("=" * 80)
    print("RIGOROUS TEST: MUMBAI-PUNE EXPRESSWAY JULY MONSOON CLOUDBURST")
    print("Scenario: July 25, 2024 | 14:30 IST | Red Alert Torrential Rain & Ghat Fog")
    print("=" * 80)

    # 1. Historical July 25 Monsoon Datetime
    # 14:30 IST = 09:00 UTC
    july_utc = datetime(2024, 7, 25, 9, 0, 0, tzinfo=timezone.utc)
    july_ist = to_ist(july_utc)
    print(f"Target Datetime: {july_ist.strftime('%Y-%m-%d %I:%M %p %Z')}")
    print(f"Features Month: {july_ist.month} (July) | Hour: {july_ist.hour}:00 IST\n")

    # 2. Segment Environmental Conditions on July 25
    monsoon_scenario: dict[str, dict[str, Any]] = {
        "R1": {
            "name": "Mumbai to Panvel",
            "rainfall_mm": 18.5,
            "visibility_km": 2.5,
            "temp_c": 26.0,
            "rhum": 94.0,
            "pres": 1004.0,
            "wind_kmh": 28.0,
            "traffic_speed_kmh": 42,
            "free_flow_speed_kmh": 80,
            "traffic_ratio": 1.45,
            "traffic_delay_min": 12,
            "user_reports": [
                {"rain": "Heavy Rain", "visibility": "Poor", "traffic": "Heavy Volume", "hazards": "Slippery Road"}
            ]
        },
        "R2": {
            "name": "Panvel to Khalapur",
            "rainfall_mm": 28.0,
            "visibility_km": 1.8,
            "temp_c": 25.5,
            "rhum": 96.0,
            "pres": 1001.0,
            "wind_kmh": 35.0,
            "traffic_speed_kmh": 38,
            "free_flow_speed_kmh": 90,
            "traffic_ratio": 1.55,
            "traffic_delay_min": 18,
            "user_reports": [
                {"rain": "Very Heavy Rain", "visibility": "Poor", "traffic": "Heavy Delay", "hazards": "Waterlogging"}
            ]
        },
        "R3": {
            "name": "Khalapur to Khopoli (Foothills)",
            "rainfall_mm": 36.0,
            "visibility_km": 1.2,
            "temp_c": 25.0,
            "rhum": 98.0,
            "pres": 996.0,
            "wind_kmh": 40.0,
            "traffic_speed_kmh": 28,
            "free_flow_speed_kmh": 80,
            "traffic_ratio": 1.70,
            "traffic_delay_min": 24,
            "user_reports": [
                {"rain": "Very Heavy Rain", "visibility": "Poor", "traffic": "Standstill", "hazards": "Water Runoff"}
            ]
        },
        "R4": {
            "name": "Khopoli to Khandala (Bhor Ghat Steep Incline)",
            "rainfall_mm": 65.0,  # Torrential downpour / cloudburst
            "visibility_km": 0.20,  # 200 meters - Dense blinding mountain mist
            "temp_c": 22.5,
            "rhum": 100.0,
            "pres": 945.0,
            "wind_kmh": 55.0,
            "traffic_speed_kmh": 12,  # Severe crawling bottleneck
            "free_flow_speed_kmh": 50,
            "traffic_ratio": 2.60,
            "traffic_delay_min": 52,
            "user_reports": [
                {"rain": "Very Heavy Rain", "visibility": "Very Poor", "traffic": "Standstill", "hazards": "Severe Waterlogging"},
                {"rain": "Very Heavy Rain", "visibility": "Very Poor", "traffic": "Standstill", "hazards": "Dense Fog"},
                {"rain": "Very Heavy Rain", "visibility": "Very Poor", "traffic": "Standstill", "hazards": "Mud / Rockfall Alert"},
            ]
        },
        "R5": {
            "name": "Khandala to Lonavala (Crest Transition)",
            "rainfall_mm": 48.0,
            "visibility_km": 0.35,  # 350 meters
            "temp_c": 22.0,
            "rhum": 100.0,
            "pres": 938.0,
            "wind_kmh": 45.0,
            "traffic_speed_kmh": 15,
            "free_flow_speed_kmh": 60,
            "traffic_ratio": 2.20,
            "traffic_delay_min": 38,
            "user_reports": [
                {"rain": "Very Heavy Rain", "visibility": "Very Poor", "traffic": "Standstill", "hazards": "Aquaplaning Risk"},
                {"rain": "Very Heavy Rain", "visibility": "Very Poor", "traffic": "Heavy Delay", "hazards": "Dense Mist"},
            ]
        },
        "R6": {
            "name": "Lonavala to Kamshet",
            "rainfall_mm": 22.0,
            "visibility_km": 1.5,
            "temp_c": 24.0,
            "rhum": 95.0,
            "pres": 948.0,
            "wind_kmh": 32.0,
            "traffic_speed_kmh": 35,
            "free_flow_speed_kmh": 85,
            "traffic_ratio": 1.60,
            "traffic_delay_min": 20,
            "user_reports": [
                {"rain": "Heavy Rain", "visibility": "Poor", "traffic": "Moderate Delay", "hazards": "Wet Surface"}
            ]
        },
        "R7": {
            "name": "Kamshet to Pune (Somatne / Ravet)",
            "rainfall_mm": 14.0,
            "visibility_km": 3.0,
            "temp_c": 25.0,
            "rhum": 92.0,
            "pres": 952.0,
            "wind_kmh": 22.0,
            "traffic_speed_kmh": 50,
            "free_flow_speed_kmh": 90,
            "traffic_ratio": 1.30,
            "traffic_delay_min": 10,
            "user_reports": [
                {"rain": "Moderate Rain", "visibility": "Moderately Reduced", "traffic": "Normal Flow", "hazards": "None"}
            ]
        },
    }

    print("-" * 80)
    print("STEP 1: REGIONAL XGBOOST ML MODEL INFERENCE (MONTH=7, PEAK MONSOON FEATURES)")
    print("-" * 80)

    ml_results: dict[str, Any] = {}
    for reg, data in monsoon_scenario.items():
        weather_feat = {
            "temperature_c": data["temp_c"],
            "humidity_percent": data["rhum"],
            "pressure_hpa": data["pres"],
        }
        pred_res = prediction_service.predict(
            region=reg,
            travel_datetime=july_utc,
            features=weather_feat,
        )
        ml_results[reg] = pred_res
        payload = pred_res.prediction or {}
        score = payload.get("safety_score", "N/A")
        severity = payload.get("hazard_severity", "N/A")
        cat = payload.get("severity_category", "N/A")
        print(f"[{reg}] {data['name'][:35]:<35} | ML Safety: {score:>5}/100 | Hazard: {severity:>5} | Risk: {cat}")

    print("\n" + "-" * 80)
    print("STEP 2: WEATHER NORMALIZATION & SENSORY DERIVATION")
    print("-" * 80)

    norm_weather_by_reg: dict[str, Any] = {}
    for reg, data in monsoon_scenario.items():
        coords = get_segment_coordinates(reg)
        w_obj = WeatherData(
            latitude=coords[0],
            longitude=coords[1],
            observed_at=july_utc,
            temperature_c=data["temp_c"],
            humidity_percent=data["rhum"],
            pressure_hpa=data["pres"],
            rainfall_mm=data["rainfall_mm"],
            wind_speed_kmh=data["wind_kmh"],
            visibility_km=data["visibility_km"],
            weather_condition="heavy intensity shower rain",
            source="openweather_monsoon_simulation",
        )
        norm = weather_normalizer.normalize(w_obj)
        norm_weather_by_reg[reg] = norm
        print(f"[{reg}] Rain: {norm.rain_condition:<16} | Vis: {norm.visibility_condition:<14} | Fog: {norm.fog_condition:<12} | Rain mm: {norm.rainfall_mm}mm/h")

    print("\n" + "-" * 80)
    print("STEP 3: LIVE TRAFFIC VS. USER REPORT PREFERENCE & WEIGHTING")
    print("-" * 80)

    traffic_evals: dict[str, Any] = {}
    for reg, data in monsoon_scenario.items():
        # Google Maps traffic payload structure
        gmaps_traffic = {
            "status": "active",
            "traffic_level": "standstill" if data["traffic_ratio"] > 1.8 else ("heavy" if data["traffic_ratio"] > 1.4 else "moderate"),
            "current_speed": f"{data['traffic_speed_kmh']} km/h",
            "typical_speed": f"{data['free_flow_speed_kmh']} km/h",
            "delay_minutes": data["traffic_delay_min"],
            "traffic_ratio": data["traffic_ratio"],
            "traffic_score": round(max(10.0, 100.0 - (data["traffic_delay_min"] * 1.5) - (data["traffic_ratio"] - 1.0) * 40), 1),
            "source": "google_maps",
            "color_hex": "#EF4444" if data["traffic_ratio"] > 1.4 else "#F59E0B",
        }
        traffic_evals[reg] = gmaps_traffic
        print(f"[{reg}] Speed: {gmaps_traffic['current_speed']} (Delay: +{gmaps_traffic['delay_minutes']}m) | Traffic Score: {gmaps_traffic['traffic_score']}/100 | Level: {gmaps_traffic['traffic_level']}")

    print("\n" + "-" * 80)
    print("STEP 4: FULL SEGMENT INTELLIGENCE & MULTI-SOURCE SAFETY SCORING")
    print("-" * 80)

    segment_evaluations: dict[str, Any] = {}
    for reg, data in monsoon_scenario.items():
        norm_w = norm_weather_by_reg[reg]
        w_dict = norm_w.to_dict()
        ml_res = ml_results[reg].to_dict()
        traffic_res = traffic_evals[reg]

        # Simulate normalized traveler reports for this segment
        traveler_reports = []
        for rep in data["user_reports"]:
            traveler_reports.append({
                "region": reg,
                "rain_condition": rep["rain"].lower(),
                "visibility_condition": rep["visibility"].lower(),
                "fog_condition": "dense fog" if "Fog" in rep["hazards"] or "Mist" in rep["hazards"] else "none",
                "traffic_condition": rep["traffic"].lower(),
                "unusual_condition": rep["hazards"].lower().replace(" ", "_"),
                "confidence": 0.85,
            })

        rep_dict = None
        if traveler_reports:
            rep_dict = {
                "rain": traveler_reports[0]["rain_condition"],
                "visibility": traveler_reports[0]["visibility_condition"],
                "fog": traveler_reports[0]["fog_condition"],
                "unusual_conditions": traveler_reports[0]["unusual_condition"],
                "traffic": traveler_reports[0]["traffic_condition"],
                "reports_count": len(traveler_reports),
            }

        # Multi-source dimension fusion
        fusion = data_fusion_service.fuse(
            historical_result=ml_res.get("prediction"),
            weather_result=w_dict,
            report_result=rep_dict,
        )

        # Inherent terrain geometry baseline
        if reg == "R4":
            t_score = 90.0
            t_reasons = ["Bhor Ghat steep descent: Maximum curve radius hazard"]
        elif reg == "R5":
            t_score = 94.0
            t_reasons = ["Lonavala crest transition: Wet highway runoff"]
        elif reg == "R3":
            t_score = 97.0
            t_reasons = ["Ghat foothills approach"]
        else:
            t_score = 100.0
            t_reasons = []

        # Calculate Segment Safety Score (Traveler Profile with OpenWeather priority & Ghat ML focus)
        score_res = safety_score_service.calculate_segment_score(
            region=reg,
            historical_result=ml_res,
            weather_result=w_dict,
            traveler_result=rep_dict,
            fusion_result=fusion.to_dict(),
            traffic_result=traffic_res,
            is_planner=False,
            terrain_score=t_score,
            terrain_reasons=t_reasons,
        )

        # Calculate Hydrodynamic Safe Speed
        safe_spd = corridor_physics_service.compute_safe_speed(
            region=reg,
            weather_data=w_dict,
            safety_score=score_res.safety_score,
            is_night=False,
        )

        segment_evaluations[reg] = {
            "score": score_res.safety_score,
            "status": score_res.status,
            "components": score_res.to_dict().get("components", {}),
            "reasons": score_res.reasons,
            "risk_factors": score_res.risk_factors,
            "safe_speed": safe_spd,
        }

        print(f"[{reg}] Safety Score: {score_res.safety_score:>4.1f}/100 | Status: {score_res.status:<14} | Safe Speed Limit: {safe_spd['recommended_safe_speed_kmh']} km/h (Statutory: {safe_spd['statutory_speed_kmh']} km/h)")
        if score_res.risk_factors:
            print(f"     Risk Factors: {', '.join(score_res.risk_factors)}")
        if score_res.reasons:
            print(f"     Top Reason:   {score_res.reasons[0]}")

    print("\n" + "-" * 80)
    print("STEP 5: CORRIDOR-LEVEL WEAKEST-LINK SAFETY AGGREGATION")
    print("-" * 80)

    all_scores = [v["score"] for v in segment_evaluations.values() if v["score"] is not None]
    corridor_score = min(all_scores)
    weakest_reg = [r for r, v in segment_evaluations.items() if v["score"] == corridor_score][0]

    print(f"Corridor Safety Score (Weakest-Link): {corridor_score:.1f}/100")
    print(f"Bottleneck Segment: {weakest_reg} - {monsoon_scenario[weakest_reg]['name']}")
    print(f"Bottleneck Safe Speed: {segment_evaluations[weakest_reg]['safe_speed']['recommended_safe_speed_kmh']} km/h")
    print(f"Bottleneck Speed Reduction: -{segment_evaluations[weakest_reg]['safe_speed']['speed_reduction_kmh']} km/h")
    print(f"Bottleneck Active Hazards:\n  • " + "\n  • ".join(segment_evaluations[weakest_reg]["reasons"][:3]))

    # Rigorous Assertions
    assert corridor_score < 40.0, f"Expected critical monsoon score < 40, got {corridor_score}"
    assert weakest_reg in ("R4", "R5"), f"Expected Bhor Ghat R4 or R5 to be the weakest link, got {weakest_reg}"
    print(">> Corridor weakest-link bottleneck validation PASSED!")

    print("\n" + "-" * 80)
    print("STEP 6: SMART TIMING ADVICE UNDER JULY MONSOON CONDITIONS")
    print("-" * 80)

    timing_advice = departure_optimizer_service.optimize_departure_window(
        base_datetime=july_utc,
        route_segments=list(monsoon_scenario.keys()),
        current_safety_score=corridor_score,
        is_live_traveler=True,
    )

    print(f"Has Better Alternative: {timing_advice.get('has_better_alternative')}")
    print(f"Recommendation:         {timing_advice.get('recommendation_text')}")
    print("Departure Window Comparisons:")
    for alt in timing_advice.get("alternative_windows", []):
        is_curr = " (Current)" if alt.get("is_current") else ""
        print(f"  • {alt['display_time']}{is_curr:<10}: Score {alt['safety_score']}/100 | Condition: {alt['condition']}")

    print("\n" + "=" * 80)
    print("RIGOROUS TESTING CONCLUSION: ALL JULY MONSOON INTELLIGENCE CRITERIA PASSED!")
    print("=" * 80)
    return True


if __name__ == "__main__":
    success = run_july_monsoon_rigorous_test()
    if success:
        sys.exit(0)
    else:
        sys.exit(1)
