from __future__ import annotations

import json

from sqlalchemy.orm import Session

from models.traveler_report import TravelerReport
from services.observation_normalizer import (
    NormalizedObservation,
    observation_normalizer,
)
from services.route_segment_service import get_segment_details


class TravelerReportService:
    """
    Handles creation and persistence of traveler observations.

    Natural-language observations are interpreted by the
    ObservationNormalizer before persistence.
    """

    def create_report(
        self,
        db: Session,
        user_id: int,
        trip_id: int | None,
        latitude: float,
        longitude: float,
        raw_message: str,
        route_region: str | None = None,
        rain: str | None = None,
        visibility: str | None = None,
        fog: str | None = None,
        unusual_conditions: str | None = None,
        traffic: str | None = None,
        normalized_data: dict | None = None,
        extraction_confidence: float | None = None,
    ) -> TravelerReport:
        """
        Create and persist a structured traveler report.

        The original user message is always preserved in
        raw_message.
        """

        self._validate_coordinates(
            latitude=latitude,
            longitude=longitude,
        )

        self._validate_raw_message(
            raw_message=raw_message,
        )

        normalized_region = self._validate_route_region(
            route_region=route_region,
        )

        normalized_confidence = self._validate_confidence(
            extraction_confidence
        )

        normalized_json = None

        if normalized_data is not None:
            normalized_json = json.dumps(
                normalized_data,
                ensure_ascii=False,
            )

        report = TravelerReport(
            user_id=user_id,
            trip_id=trip_id,
            latitude=latitude,
            longitude=longitude,
            route_region=normalized_region,
            raw_message=raw_message.strip(),
            rain=rain,
            visibility=visibility,
            fog=fog,
            unusual_conditions=unusual_conditions,
            traffic=traffic,
            normalized_data=normalized_json,
            extraction_confidence=normalized_confidence,
        )

        db.add(report)
        db.commit()
        db.refresh(report)

        return report

    def create_report_from_message(
        self,
        db: Session,
        user_id: int,
        trip_id: int | None,
        latitude: float,
        longitude: float,
        raw_message: str,
        route_region: str | None = None,
    ) -> tuple[TravelerReport | None, NormalizedObservation]:
        """
        Convert a natural-language traveler message into a
        structured observation and persist it.

        If the observation requires clarification, no database
        report is created. The caller should return the
        clarification question to the user.
        """

        observation = observation_normalizer.normalize(
            raw_message
        )

        if observation.needs_clarification:
            return None, observation

        normalized_data = observation.to_dict()

        report = self.create_report(
            db=db,
            user_id=user_id,
            trip_id=trip_id,
            latitude=latitude,
            longitude=longitude,
            raw_message=observation.raw_text,
            route_region=route_region,
            rain=observation.rain,
            visibility=observation.visibility,
            fog=observation.fog,
            unusual_conditions=observation.unusual_conditions,
            traffic=observation.traffic,
            normalized_data=normalized_data,
            extraction_confidence=observation.confidence,
        )

        return report, observation

    @staticmethod
    def _validate_coordinates(
        latitude: float,
        longitude: float,
    ) -> None:
        if not -90 <= latitude <= 90:
            raise ValueError(
                f"Invalid latitude: {latitude}"
            )

        if not -180 <= longitude <= 180:
            raise ValueError(
                f"Invalid longitude: {longitude}"
            )

    @staticmethod
    def _validate_raw_message(
        raw_message: str,
    ) -> None:
        if not isinstance(raw_message, str):
            raise ValueError(
                "Traveler observation must be a string."
            )

        if not raw_message.strip():
            raise ValueError(
                "Traveler observation cannot be empty."
            )

    @staticmethod
    def _validate_route_region(
        route_region: str | None,
    ) -> str | None:
        if route_region is None:
            return None

        if not isinstance(route_region, str):
            raise ValueError(
                "Route region must be a string."
            )

        normalized_region = route_region.strip().upper()

        if not normalized_region:
            return None

        get_segment_details(normalized_region)

        return normalized_region

    @staticmethod
    def _validate_confidence(
        confidence: float | None,
    ) -> float | None:
        if confidence is None:
            return None

        if not 0 <= confidence <= 1:
            raise ValueError(
                "Extraction confidence must be between 0 and 1."
            )

        return confidence

    @staticmethod
    def get_report(
        db: Session,
        report_id: int,
    ) -> TravelerReport | None:
        """
        Retrieve a single traveler report by ID.
        """

        return (
            db.query(TravelerReport)
            .filter(
                TravelerReport.id == report_id,
            )
            .first()
        )

    @staticmethod
    def get_user_reports(
        db: Session,
        user_id: int,
        limit: int = 50,
    ) -> list[TravelerReport]:
        """
        Retrieve recent reports belonging to a user.
        """

        if limit < 1:
            raise ValueError(
                "Limit must be greater than zero."
            )

        return (
            db.query(TravelerReport)
            .filter(
                TravelerReport.user_id == user_id,
            )
            .order_by(
                TravelerReport.created_at.desc(),
            )
            .limit(limit)
            .all()
        )

    @staticmethod
    def get_region_reports(
        db: Session,
        route_region: str,
        limit: int = 100,
    ) -> list[TravelerReport]:
        """
        Retrieve recent reports for a route region.
        """

        normalized_region = route_region.strip().upper()

        get_segment_details(normalized_region)

        if limit < 1:
            raise ValueError(
                "Limit must be greater than zero."
            )

        return (
            db.query(TravelerReport)
            .filter(
                TravelerReport.route_region
                == normalized_region,
            )
            .order_by(
                TravelerReport.created_at.desc(),
            )
            .limit(limit)
            .all()
        )


traveler_report_service = TravelerReportService()