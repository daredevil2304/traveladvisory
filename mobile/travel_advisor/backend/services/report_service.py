from sqlalchemy.orm import Session

from models.trip import Trip
from models.travel_report import TravelReport


class ReportService:
    """
    Handles creation, retrieval, and deletion of saved
    travel analysis reports.
    """

    # ================================================================
    # SAVE REPORT
    # ================================================================

    def save_report(
        self,
        db: Session,
        user_id: int,
        trip_id: int,
        title: str,
        analysis_data: dict,
    ) -> TravelReport:
        """
        Save a completed trip analysis as a persistent report.
        """

        # ------------------------------------------------------------
        # 1. Verify trip exists
        # ------------------------------------------------------------

        trip = (
            db.query(Trip)
            .filter(
                Trip.id == trip_id,
                Trip.user_id == user_id,
            )
            .first()
        )

        if trip is None:
            raise ValueError(
                "Trip not found or does not belong to this user."
            )

        # ------------------------------------------------------------
        # 2. Extract high-level analysis values
        # ------------------------------------------------------------

        safety_score = self._get_float(
            analysis_data,
            "overall_safety_score",
            "overallSafetyScore",
            "safety_score",
            "safetyScore",
        )

        confidence = self._get_float(
            analysis_data,
            "overall_confidence",
            "overallConfidence",
            "confidence",
        )

        advisory = self._get_string(
            analysis_data,
            "final_advisory",
            "finalAdvisory",
            "advisory",
        )

        # ------------------------------------------------------------
        # 3. Create saved report
        # ------------------------------------------------------------

        report = TravelReport(
            user_id=user_id,
            trip_id=trip.id,
            title=title.strip(),
            source_name=trip.source_name,
            destination_name=trip.destination_name,
            role=trip.role,
            travel_datetime=trip.travel_datetime,
            safety_score=safety_score,
            confidence=confidence,
            advisory=advisory,
            analysis_data=analysis_data,
        )

        db.add(report)
        db.commit()
        db.refresh(report)

        return report

    # ================================================================
    # GET USER REPORTS
    # ================================================================

    def get_user_reports(
        self,
        db: Session,
        user_id: int,
    ) -> list[TravelReport]:
        """
        Return all saved reports belonging to a user.
        """

        return (
            db.query(TravelReport)
            .filter(
                TravelReport.user_id == user_id,
            )
            .order_by(
                TravelReport.created_at.desc()
            )
            .all()
        )

    # ================================================================
    # GET SINGLE REPORT
    # ================================================================

    def get_report(
        self,
        db: Session,
        user_id: int,
        report_id: int,
    ) -> TravelReport | None:
        """
        Return one saved report belonging to the user.
        """

        return (
            db.query(TravelReport)
            .filter(
                TravelReport.id == report_id,
                TravelReport.user_id == user_id,
            )
            .first()
        )

    # ================================================================
    # DELETE REPORT
    # ================================================================

    def delete_report(
        self,
        db: Session,
        user_id: int,
        report_id: int,
    ) -> bool:
        """
        Delete one saved report belonging to the user.
        """

        report = self.get_report(
            db=db,
            user_id=user_id,
            report_id=report_id,
        )

        if report is None:
            return False

        db.delete(report)
        db.commit()

        return True

    # ================================================================
    # HELPERS
    # ================================================================

    @staticmethod
    def _get_float(
        data: dict,
        *keys: str,
    ) -> float | None:
        """
        Read a numeric value while supporting both
        snake_case and camelCase backend fields.
        """

        for key in keys:
            value = data.get(key)

            if value is None:
                continue

            try:
                return float(value)
            except (TypeError, ValueError):
                continue

        return None

    @staticmethod
    def _get_string(
        data: dict,
        *keys: str,
    ) -> str | None:
        """
        Read a string value while supporting multiple
        possible analysis field names.
        """

        for key in keys:
            value = data.get(key)

            if value is None:
                continue

            if isinstance(value, str):
                return value

        return None


report_service = ReportService()