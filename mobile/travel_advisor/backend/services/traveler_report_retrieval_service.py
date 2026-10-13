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

    def get_recent_reports(
        self,
        db: Session,
        region: str,
        reference_datetime: datetime,
        lookback_hours: int = 6,
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

        start_datetime = (
            reference_datetime
            - timedelta(hours=lookback_hours)
        )

        statement = (
            select(TravelerReport)
            .where(
                TravelerReport.route_region == normalized_region,
                TravelerReport.created_at >= start_datetime,
                TravelerReport.created_at <= reference_datetime,
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
        lookback_hours: int = 6,
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
        lookback_hours: int = 6,
        limit_per_region: int = 20,
    ) -> dict[str, list[TravelerReport]]:
        """
        Retrieve reports for every route region involved in a trip.

        Example:

            {
                "R1": [...],
                "R2": [...],
                "R3": [...]
            }
        """

        results: dict[str, list[TravelerReport]] = {}

        for region in regions:
            normalized_region = self._normalize_region(region)

            results[normalized_region] = self.get_recent_reports(
                db=db,
                region=normalized_region,
                reference_datetime=reference_datetime,
                lookback_hours=lookback_hours,
                limit=limit_per_region,
            )

        return results

    def serialize_report(
        self,
        report: TravelerReport,
    ) -> dict:
        """
        Convert a database report into a JSON-safe dictionary.

        The stored normalized_data is preserved as-is because the
        later fusion layer may need the normalized observations.
        """

        return {
            "id": report.id,
            "user_id": report.user_id,
            "trip_id": report.trip_id,
            "latitude": report.latitude,
            "longitude": report.longitude,
            "route_region": report.route_region,
            "raw_message": report.raw_message,
            "rain": report.rain,
            "visibility": report.visibility,
            "fog": report.fog,
            "unusual_conditions": report.unusual_conditions,
            "traffic": report.traffic,
            "normalized_data": report.normalized_data,
            "extraction_confidence": report.extraction_confidence,
            "created_at": (
                report.created_at.isoformat()
                if report.created_at
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