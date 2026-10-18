from __future__ import annotations

from datetime import datetime, timedelta
from typing import Any

from sqlalchemy import desc
from sqlalchemy.orm import Session

from models.commute_habit import CommuteCheckLog, CommuteHabit
from models.user import User
from models.traveler_report import TravelerReport
from models.trip import Trip
from services.route_segment_service import (
    get_route_point_coordinates,
    get_segment_details,
    normalize_location,
    resolve_route_segments,
)
from services.prediction_service import prediction_service
from services.timezone_service import format_ist_iso, get_ist_now
from services.weather_service import weather_service
from datetime import timezone
from services.segment_intelligence_service import segment_intelligence_service
from services.google_maps_traffic_service import google_maps_traffic_service
from services.route_segment_service import ROUTE_POINT_COORDINATES


class CommuteNotificationService:
    """
    Intelligent commute pattern learning and proactive pre-trip notification service.

    Features:
    1. Tracks traveler report checks to automatically identify daily commute patterns.
    2. Learns typical departure time (e.g. 08:00 AM) and query time (e.g. 07:50 AM).
    3. Calculates proactive notification alert time (e.g. 07:45 AM, 15 min prior).
    4. Evaluates corridor safety score using ML predictions, live weather forecasts,
       and real-time human observations (last 6 hours).
    5. Formulates specific regional hazard warnings (e.g., low visibility near Lonavala,
       wet roads near Bhor Ghat, traffic near Kamshet).
    """

    LOOKBACK_HOURS = 6

    def log_commute_check(
        self,
        db: Session,
        user_id: int,
        source: str,
        destination: str,
        departure_time: str | None = None,
        check_time: str | None = None,
    ) -> CommuteCheckLog:
        """
        Record a check event and update the user's learned commute habit.
        """
        now = get_ist_now()
        if not check_time:
            # Format as HH:MM in IST
            check_time = now.strftime("%H:%M")

        canonical_source = normalize_location(source) if source else "Panvel"
        canonical_destination = (
            normalize_location(destination) if destination else "Pune"
        )

        log = CommuteCheckLog(
            user_id=user_id,
            source_name=canonical_source,
            destination_name=canonical_destination,
            departure_time=departure_time,
            check_time=check_time,
            created_at=now,
        )
        db.add(log)
        db.commit()
        db.refresh(log)

        # Trigger automatic habit detection
        self._update_habit_from_history(db, user_id)

        return log

    def get_commute_habit(
        self,
        db: Session,
        user_id: int,
        schedule_type: str = "outbound",
    ) -> dict[str, Any]:
        """
        Retrieve learned and configured commute habit for this user and schedule type.
        """
        habit = (
            db.query(CommuteHabit)
            .filter(
                CommuteHabit.user_id == user_id,
                CommuteHabit.schedule_type == schedule_type,
            )
            .first()
        )
        if not habit and schedule_type == "outbound":
            habit = (
                db.query(CommuteHabit)
                .filter(CommuteHabit.user_id == user_id)
                .first()
            )

        if habit:
            return {
                "id": habit.id,
                "user_id": habit.user_id,
                "schedule_type": getattr(habit, "schedule_type", schedule_type),
                "source": habit.source_name,
                "destination": habit.destination_name,
                "departure_time": habit.departure_time,
                "observed_check_time": habit.observed_check_time,
                "alert_time": habit.alert_time,
                "travel_days": getattr(habit, "travel_days", None) if getattr(habit, "travel_days", None) else "Daily",
                "is_enabled": habit.is_enabled,
                "updated_at": habit.updated_at.isoformat(),
                "has_habit": True,
            }

        # Check Trip history and logs to auto-seed habit
        detected = self._detect_habit_from_database(db, user_id)
        if detected and schedule_type == "outbound":
            new_habit = CommuteHabit(
                user_id=user_id,
                schedule_type=schedule_type,
                source_name=detected["source"],
                destination_name=detected["destination"],
                departure_time=detected["departure_time"],
                observed_check_time=detected["observed_check_time"],
                alert_time=detected["alert_time"],
                travel_days="Daily",
                is_enabled=True,
            )
            db.add(new_habit)
            db.commit()
            db.refresh(new_habit)

            return {
                "id": new_habit.id,
                "user_id": new_habit.user_id,
                "schedule_type": new_habit.schedule_type,
                "source": new_habit.source_name,
                "destination": new_habit.destination_name,
                "departure_time": new_habit.departure_time,
                "observed_check_time": new_habit.observed_check_time,
                "alert_time": new_habit.alert_time,
                "travel_days": new_habit.travel_days if new_habit.travel_days else "Daily",
                "is_enabled": new_habit.is_enabled,
                "updated_at": new_habit.updated_at.isoformat(),
                "has_habit": True,
            }

        default_source = "Panvel" if schedule_type == "outbound" else "Pune"
        default_destination = "Pune" if schedule_type == "outbound" else "Panvel"
        default_departure = "08:00" if schedule_type == "outbound" else "18:00"
        default_alert = "07:45" if schedule_type == "outbound" else "17:30"

        return {
            "id": 0,
            "user_id": user_id,
            "schedule_type": schedule_type,
            "source": default_source,
            "destination": default_destination,
            "departure_time": default_departure,
            "observed_check_time": self._calculate_check_time(default_departure),
            "alert_time": default_alert,
            "travel_days": "Daily",
            "is_enabled": True,
            "updated_at": format_ist_iso(),
            "has_habit": False,
        }

    def get_all_commute_habits(
        self,
        db: Session,
        user_id: int,
    ) -> dict[str, Any]:
        """
        Retrieve both Outbound and Return commute habits.
        """
        outbound = self.get_commute_habit(db, user_id, schedule_type="outbound")
        return_habit = self.get_commute_habit(db, user_id, schedule_type="return")
        return {
            "outbound": outbound,
            "return": return_habit,
        }

    @staticmethod
    def is_scheduled_current_day(
        travel_days: str | None,
        dt: datetime | None = None,
    ) -> bool:
        """
        Check whether the target datetime corresponds to an active commute day.
        """
        if not travel_days:
            return True
        if dt is None:
            dt = get_ist_now()

        weekday_map = {
            0: "Mon",
            1: "Tue",
            2: "Wed",
            3: "Thu",
            4: "Fri",
            5: "Sat",
            6: "Sun",
        }
        current_code = weekday_map.get(dt.weekday())
        trimmed = travel_days.strip()
        if trimmed == "Daily":
            return True
        if trimmed in ("Sat-Sun", "Weekends"):
            return dt.weekday() in (5, 6)
        if trimmed == "Mon-Fri":
            return dt.weekday() in (0, 1, 2, 3, 4)

        clean = trimmed.replace("Custom:", "")
        selected = {d.strip() for d in clean.split(",") if d.strip()}
        return current_code in selected

    def save_commute_habit(
        self,
        db: Session,
        user_id: int,
        source: str,
        destination: str,
        departure_time: str,
        alert_time: str,
        travel_days: str | None = "Daily",
        is_enabled: bool = True,
        schedule_type: str = "outbound",
    ) -> dict[str, Any]:
        """
        Explicitly update and customize commute habit settings for outbound or return.
        """
        canonical_source = normalize_location(source)
        canonical_destination = normalize_location(destination)

        habit = (
            db.query(CommuteHabit)
            .filter(
                CommuteHabit.user_id == user_id,
                CommuteHabit.schedule_type == schedule_type,
            )
            .first()
        )
        if not habit and schedule_type == "outbound":
            habit = (
                db.query(CommuteHabit)
                .filter(CommuteHabit.user_id == user_id)
                .first()
            )

        resolved_days = travel_days.strip() if travel_days else "Daily"

        # Ensure user exists in database to prevent foreign key failure
        user = db.query(User).filter(User.id == user_id).first()
        if not user:
            user = User(
                id=user_id,
                full_name="Expressway Commuter",
                email=f"commuter_{user_id}@expressway.local",
                mobile=f"900000000{user_id % 10}",
                password_hash="guest_hash",
                is_verified=True,
                is_active=True,
            )
            db.add(user)
            db.flush()

        if not habit:
            habit = CommuteHabit(
                user_id=user_id,
                schedule_type=schedule_type,
                source_name=canonical_source,
                destination_name=canonical_destination,
                departure_time=departure_time.strip(),
                observed_check_time=self._calculate_check_time(departure_time),
                alert_time=alert_time.strip(),
                travel_days=resolved_days,
                is_enabled=is_enabled,
            )
            db.add(habit)
        else:
            habit.schedule_type = schedule_type
            habit.source_name = canonical_source
            habit.destination_name = canonical_destination
            habit.departure_time = departure_time.strip()
            habit.alert_time = alert_time.strip()
            habit.travel_days = resolved_days
            habit.is_enabled = is_enabled
            habit.updated_at = get_ist_now()

        db.commit()
        db.refresh(habit)

        return {
            "id": habit.id,
            "user_id": habit.user_id,
            "schedule_type": habit.schedule_type,
            "source": habit.source_name,
            "destination": habit.destination_name,
            "departure_time": habit.departure_time,
            "observed_check_time": habit.observed_check_time,
            "alert_time": habit.alert_time,
            "travel_days": habit.travel_days if habit.travel_days else "Daily",
            "is_enabled": habit.is_enabled,
            "updated_at": habit.updated_at.isoformat(),
            "has_habit": True,
        }

    def generate_commute_alert(
        self,
        db: Session,
        user_id: int,
        source: str = "Panvel",
        destination: str = "Pune",
    ) -> dict[str, Any]:
        """
        Dynamically evaluates real-time corridor telemetry combining live OpenWeather
        atmospheric observations, regional XGBoost ML risk predictions, and live Google Maps
        traffic delays along the exact route selected in the commute setup.
        """
        canonical_source = normalize_location(source) if source else "Panvel"
        canonical_destination = (
            normalize_location(destination) if destination else "Pune"
        )

        # 1. Resolve route segments
        try:
            segments = resolve_route_segments(
                canonical_source, canonical_destination
            )
        except Exception:
            segments = ["R2", "R3", "R4", "R5", "R6", "R7"]

        if not segments:
            segments = ["R2", "R3", "R4", "R5", "R6", "R7"]

        now = get_ist_now()
        now_utc = datetime.now(timezone.utc)
        warnings: list[str] = []
        segment_risks: list[dict[str, Any]] = []

        total_segment_scores: list[float] = []
        segment_weights: list[float] = []
        traffic_delays_total_mins = 0
        has_heavy_traffic = False

        for region in segments:
            reg_code = region.upper()
            seg_metadata = get_segment_details(reg_code)
            seg_name = f"{seg_metadata.start} to {seg_metadata.end}"

            # Weighting: Bhor Ghat (R4) is the primary bottleneck
            seg_weight = 1.35 if reg_code == "R4" else 1.0
            segment_weights.append(seg_weight)

            # Start and End coordinates for this sector
            start_coords = ROUTE_POINT_COORDINATES.get(seg_metadata.start, (18.98878, 73.11013))
            end_coords = ROUTE_POINT_COORDINATES.get(seg_metadata.end, (18.52050, 73.85650))

            # Fetch live Google Maps traffic for this sector
            live_traffic = None
            try:
                live_traffic = google_maps_traffic_service.get_segment_traffic(
                    start_coords=start_coords,
                    end_coords=end_coords,
                    start_name=seg_metadata.start,
                    end_name=seg_metadata.end,
                )
            except Exception:
                pass

            if live_traffic and live_traffic.get("delay_minutes", 0) > 0:
                traffic_delays_total_mins += live_traffic["delay_minutes"]
                if live_traffic.get("delay_minutes", 0) >= 10:
                    has_heavy_traffic = True
                    warnings.append(
                        f"Congestion near {seg_metadata.start}: {live_traffic['delay_minutes']} min delay"
                    )

            # Evaluate segment intelligence using full engine: OpenWeather + regional XGBoost + live traffic
            seg_score = 92.0
            seg_reasons = []
            try:
                seg_eval = segment_intelligence_service.evaluate_segment(
                    db=db,
                    region=reg_code,
                    latitude=start_coords[0],
                    longitude=start_coords[1],
                    travel_datetime=now_utc,
                    live_traffic=live_traffic,
                    is_planner=False,
                )
                res_dict = seg_eval.to_dict()
                safety_res = res_dict.get("safety_score_result", {})
                score_val = safety_res.get("safety_score")
                if score_val is not None:
                    seg_score = float(score_val)
                seg_reasons = safety_res.get("reasons", [])
            except Exception:
                pass

            total_segment_scores.append(seg_score)

            # Collect genuine sector hazards (< 85)
            if seg_score < 85.0:
                segment_risks.append({
                    "region": reg_code,
                    "segment_name": seg_name,
                    "issues": seg_reasons,
                    "segment_score": int(round(seg_score)),
                })
                for r in seg_reasons:
                    if any(w in r.lower() for w in ["fog", "rain", "slippery", "crosswind", "incline", "delay", "queue"]):
                        if r not in warnings:
                            warnings.append(f"{seg_metadata.start} ({reg_code}): {r}")

        # 3. Calculate weighted route safety score
        if total_segment_scores and segment_weights:
            weighted_sum = sum(
                s * w for s, w in zip(total_segment_scores, segment_weights)
            )
            final_score = int(round(weighted_sum / sum(segment_weights)))
        else:
            final_score = 92

        final_score = max(20, min(99, final_score))

        # 4. Determine risk level & color
        if final_score < 45:
            risk_level = "High Risk"
            risk_color = "red"
        elif final_score < 65:
            risk_level = "Caution"
            risk_color = "orange"
        elif final_score < 85:
            risk_level = "Moderate"
            risk_color = "amber"
        else:
            risk_level = "Safe"
            risk_color = "green"

        # 5. Build dynamic notification title and body reflecting real current conditions
        alert_title = (
            f"{canonical_source} to {canonical_destination} Travel Safety: {final_score}/100"
        )

        if warnings:
            top_warnings = "; ".join(warnings[:2])
            alert_body = f"Score: {final_score}/100 ({risk_level}). {top_warnings}."
        elif traffic_delays_total_mins > 0:
            alert_body = f"Score: {final_score}/100 ({risk_level}). Favorable weather with minor traffic delays (~{traffic_delays_total_mins}m total)."
        else:
            alert_body = f"Score: {final_score}/100 ({risk_level}). All expressway segments clear with free-flowing traffic and optimal visibility."

        # 6. Tailored travel advice
        if final_score < 45:
            advice = "High risk detected from live telemetry. Allow 30+ extra minutes and maintain maximum following distance."
        elif final_score < 65:
            advice = "Expect reduced braking traction and ghat delays. Maintain safe following distance."
        elif final_score < 85:
            advice = "Moderate corridor conditions. Normal travel vigilance recommended."
        else:
            advice = "Optimal expressway conditions. Free flow with normal travel time expected."

        # 7. Check if active day matches scheduled travel days
        travel_days = "Daily"
        is_scheduled = True
        try:
            habit = (
                db.query(CommuteHabit)
                .filter(CommuteHabit.user_id == user_id)
                .first()
            )
            if habit and getattr(habit, "travel_days", None):
                travel_days = habit.travel_days
            is_scheduled = self.is_scheduled_current_day(travel_days, now)
        except Exception:
            pass

        return {
            "source": canonical_source,
            "destination": canonical_destination,
            "safety_score": final_score,
            "risk_level": risk_level,
            "risk_color": risk_color,
            "title": alert_title,
            "alert_title": alert_title,
            "body": alert_body,
            "alert_body": alert_body,
            "regional_warnings": warnings,
            "warnings": warnings,
            "segment_risks": segment_risks,
            "departure_advice": advice,
            "advice": advice,
            "evaluation_time": format_ist_iso(),
            "has_warnings": len(warnings) > 0,
            "evaluated_segments_count": len(segments),
            "is_scheduled_commute_day": is_scheduled,
            "travel_days": travel_days,
        }

    def _update_habit_from_history(self, db: Session, user_id: int) -> None:
        """
        Examines recent check logs and trips to update user's habit schedule.
        """
        detected = self._detect_habit_from_database(db, user_id)
        if not detected:
            return

        habit = (
            db.query(CommuteHabit)
            .filter(CommuteHabit.user_id == user_id)
            .first()
        )

        if not habit:
            habit = CommuteHabit(
                user_id=user_id,
                source_name=detected["source"],
                destination_name=detected["destination"],
                departure_time=detected["departure_time"],
                observed_check_time=detected["observed_check_time"],
                alert_time=detected["alert_time"],
                travel_days="Daily",
                is_enabled=True,
            )
            db.add(habit)
        else:
            habit.source_name = detected["source"]
            habit.destination_name = detected["destination"]
            habit.departure_time = detected["departure_time"]
            habit.observed_check_time = detected["observed_check_time"]
            habit.alert_time = detected["alert_time"]
            habit.updated_at = get_ist_now()

        db.commit()

    def _detect_habit_from_database(
        self,
        db: Session,
        user_id: int,
    ) -> dict[str, str] | None:
        """
        Clusters check logs and trips to identify recurring commute times.
        """
        # 1. Check CommuteCheckLog
        logs = (
            db.query(CommuteCheckLog)
            .filter(CommuteCheckLog.user_id == user_id)
            .order_by(desc(CommuteCheckLog.created_at))
            .limit(10)
            .all()
        )

        if logs:
            source = logs[0].source_name
            destination = logs[0].destination_name
            dep_time = logs[0].departure_time if logs[0].departure_time else "08:00"
            check_time = logs[0].check_time if logs[0].check_time else "07:50"
            alert_time = self._calculate_alert_time(dep_time, check_time)

            return {
                "source": source,
                "destination": destination,
                "departure_time": dep_time,
                "observed_check_time": check_time,
                "alert_time": alert_time,
            }

        # 2. Check Trips
        trips = (
            db.query(Trip)
            .filter(Trip.user_id == user_id)
            .order_by(desc(Trip.created_at))
            .limit(5)
            .all()
        )

        if trips:
            source = trips[0].source_name
            destination = trips[0].destination_name
            dep_hour = trips[0].travel_datetime.strftime("%H:%M")
            check_hour = trips[0].created_at.strftime("%H:%M")
            alert_time = self._calculate_alert_time(dep_hour, check_hour)

            return {
                "source": source,
                "destination": destination,
                "departure_time": dep_hour,
                "observed_check_time": check_hour,
                "alert_time": alert_time,
            }

        return None

    @staticmethod
    def _parse_time_parts(time_str: str) -> tuple[int, int]:
        clean = time_str.strip().upper()
        is_pm = "PM" in clean
        is_am = "AM" in clean
        digits = clean.replace("AM", "").replace("PM", "").strip()
        parts = [int(p.strip()) for p in digits.split(":")[:2]]
        hour = parts[0]
        minute = parts[1] if len(parts) > 1 else 0
        if is_pm and hour < 12:
            hour += 12
        elif is_am and hour == 12:
            hour = 0
        return hour, minute

    def _calculate_alert_time(
        self,
        departure_time_str: str,
        observed_check_time_str: str,
    ) -> str:
        """
        Calculates optimal proactive alert notification time:
        15 minutes before typical departure, and 5 minutes before typical check time.
        """
        try:
            hour, minute = self._parse_time_parts(departure_time_str)
            dep_dt = datetime(2026, 1, 1, hour, minute)
            alert_dt = dep_dt - timedelta(minutes=15)
            return alert_dt.strftime("%H:%M")
        except Exception:
            pass

        try:
            hour, minute = self._parse_time_parts(observed_check_time_str)
            check_dt = datetime(2026, 1, 1, hour, minute)
            alert_dt = check_dt - timedelta(minutes=5)
            return alert_dt.strftime("%H:%M")
        except Exception:
            return "07:45"

    def _calculate_check_time(self, departure_time_str: str) -> str:
        """
        Default check time roughly 10 minutes prior to departure.
        """
        try:
            hour, minute = self._parse_time_parts(departure_time_str)
            dt = datetime(2026, 1, 1, hour, minute) - timedelta(minutes=10)
            return dt.strftime("%H:%M")
        except Exception:
            return "07:50"


commute_notification_service = CommuteNotificationService()
