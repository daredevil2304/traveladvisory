from __future__ import annotations

from datetime import datetime, timedelta

from sqlalchemy import select
from sqlalchemy.orm import Session

from models.traveler_report import TravelerReport


class TravelerReportRetrievalService:
    """
    Retrieves recent traveler observations for route regions.

    This service only retrieves and organizes stored observations.
    It does NOT decide whether a condition is safe or unsafe.

    Safety interpretation belongs to the later fusion/safety layer.
    """

    @staticmethod
    def _to_db_datetime(dt: datetime) -> datetime:
        """
        Normalize reference datetime to naive IST matching TravelerReport.created_at.
        """
        if dt.tzinfo is not None:
            from services.timezone_service import to_ist
            return to_ist(dt).replace(tzinfo=None)
        from services.timezone_service import get_ist_now
        ist_now = get_ist_now()
        diff = (ist_now - dt).total_seconds()
        if 18000 <= diff <= 21600:
            return dt + timedelta(hours=5, minutes=30)
        return dt

    def get_recent_reports(
        self,
        db: Session,
        region: str,
        reference_datetime: datetime,
        lookback_hours: int = 1,
        limit: int = 20,
    ) -> list[TravelerReport]:
        """
        Return recent reports for a specific route region.

        Reports are ordered from newest to oldest.
        """

        if not isinstance(reference_datetime, datetime):
            raise ValueError(
                "reference_datetime must be a datetime object."
            )

        if lookback_hours < 0:
            raise ValueError(
                "lookback_hours cannot be negative."
            )

        if limit < 1:
            raise ValueError(
                "limit must be at least 1."
            )

        normalized_region = self._normalize_region(region)

        ref_dt = self._to_db_datetime(reference_datetime)
        start_datetime = ref_dt - timedelta(hours=lookback_hours)
        end_datetime = ref_dt + timedelta(minutes=5)

        statement = (
            select(TravelerReport)
            .where(
                TravelerReport.route_region == normalized_region,
                TravelerReport.created_at >= start_datetime,
                TravelerReport.created_at <= end_datetime,
            )
            .order_by(
                TravelerReport.created_at.desc()
            )
            .limit(limit)
        )

        result = db.execute(statement)

        return list(result.scalars().all())

    def get_latest_report(
        self,
        db: Session,
        region: str,
        reference_datetime: datetime,
        lookback_hours: int = 1,
    ) -> TravelerReport | None:
        """
        Return the newest available traveler report for a region.
        """

        reports = self.get_recent_reports(
            db=db,
            region=region,
            reference_datetime=reference_datetime,
            lookback_hours=lookback_hours,
            limit=1,
        )

        if not reports:
            return None

        return reports[0]

    def get_reports_for_regions(
        self,
        db: Session,
        regions: list[str],
        reference_datetime: datetime,
        lookback_hours: int = 1,
        limit_per_region: int = 20,
    ) -> dict[str, list[TravelerReport]]:
        """
        Retrieve reports for all route regions involved in a trip in a single SQL query.

        Example:
            {
                "R1": [...],
                "R2": [...],
                "R3": [...]
            }
        """
        results: dict[str, list[TravelerReport]] = {
            self._normalize_region(r): [] for r in regions
        }

        if not results:
            return results

        ref_dt = self._to_db_datetime(reference_datetime)
        start_datetime = ref_dt - timedelta(hours=lookback_hours)
        end_datetime = ref_dt + timedelta(minutes=5)

        statement = (
            select(TravelerReport)
            .where(
                TravelerReport.route_region.in_(list(results.keys())),
                TravelerReport.created_at >= start_datetime,
                TravelerReport.created_at <= end_datetime,
            )
            .order_by(
                TravelerReport.created_at.desc()
            )
        )

        all_reports = list(db.execute(statement).scalars().all())
        for report in all_reports:
            reg = report.route_region
            if reg in results and len(results[reg]) < limit_per_region:
                results[reg].append(report)

        return results

    def serialize_report(
        self,
        report: Any,
    ) -> dict:
        """
        Convert a database report or dict into a JSON-safe dictionary.

        The stored normalized_data is preserved as-is because the
        later fusion layer may need the normalized observations.
        """
        if isinstance(report, dict):
            return report

        created = getattr(report, "created_at", None)
        return {
            "id": getattr(report, "id", None),
            "user_id": getattr(report, "user_id", None),
            "trip_id": getattr(report, "trip_id", None),
            "latitude": getattr(report, "latitude", None),
            "longitude": getattr(report, "longitude", None),
            "route_region": getattr(report, "route_region", None),
            "raw_message": getattr(report, "raw_message", None),
            "rain": getattr(report, "rain", None),
            "visibility": getattr(report, "visibility", None),
            "fog": getattr(report, "fog", None),
            "unusual_conditions": getattr(report, "unusual_conditions", None),
            "traffic": getattr(report, "traffic", None),
            "normalized_data": getattr(report, "normalized_data", None),
            "extraction_confidence": getattr(report, "extraction_confidence", None),
            "created_at": (
                created.isoformat()
                if created and hasattr(created, "isoformat")
                else None
            ),
        }

    def serialize_reports(
        self,
        reports: list[TravelerReport],
    ) -> list[dict]:
        """
        Serialize multiple reports.
        """

        return [
            self.serialize_report(report)
            for report in reports
        ]

    @staticmethod
    def _normalize_region(region: str) -> str:
        """
        Normalize route region identifiers.
        """

        if not isinstance(region, str):
            raise ValueError(
                "region must be a string."
            )

        normalized_region = region.strip().upper()

        if normalized_region not in {
            "R1",
            "R2",
            "R3",
            "R4",
            "R5",
            "R6",
            "R7",
        }:
            raise ValueError(
                f"Unsupported route region: {normalized_region}."
            )

        return normalized_region


# Shared service instance.
traveler_report_retrieval_service = (
    TravelerReportRetrievalService()
)