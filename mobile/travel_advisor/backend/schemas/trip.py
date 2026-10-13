from datetime import date, time

from pydantic import BaseModel, Field, model_validator


class TravelerReport(BaseModel):
    rain: str | None = Field(
        default=None,
        max_length=100,
    )

    visibility: str | None = Field(
        default=None,
        max_length=100,
    )

    fog: str | None = Field(
        default=None,
        max_length=100,
    )

    unusual_conditions: str | None = Field(
        default=None,
        max_length=500,
    )

    traffic: str | None = Field(
        default=None,
        max_length=100,
    )


class TravelerObservationRequest(BaseModel):
    user_id: int | None = Field(default=None)
    latitude: float | None = Field(default=None)
    longitude: float | None = Field(default=None)
    route_region: str | None = Field(default=None, max_length=50)
    rain: str | None = Field(default=None, max_length=100)
    visibility: str | None = Field(default=None, max_length=100)
    fog: str | None = Field(default=None, max_length=100)
    unusual_conditions: str | None = Field(default=None, max_length=500)
    traffic: str | None = Field(default=None, max_length=100)
    raw_message: str | None = Field(default=None, max_length=1000)


class TripRequest(BaseModel):
    user_id: int = Field(
        ge=1,
    )

    role: str = Field(
        min_length=1,
        max_length=20,
    )

    source: str = Field(
        min_length=1,
        max_length=150,
    )

    latitude: float = Field(
        ge=-90,
        le=90,
    )

    longitude: float = Field(
        ge=-180,
        le=180,
    )

    destination: str = Field(
        min_length=1,
        max_length=150,
    )

    travel_date: date | None = None

    travel_time: time | None = None

    traveler_report: TravelerReport | None = None

    @model_validator(mode="after")
    def validate_role_data(self):
        if self.role not in {
            "traveler",
            "planner",
        }:
            raise ValueError(
                "Role must be either 'traveler' or 'planner'."
            )

        if self.role == "planner":
            if self.travel_date is None:
                raise ValueError(
                    "Travel date is required for planner journeys."
                )

            if self.travel_time is None:
                raise ValueError(
                    "Travel time is required for planner journeys."
                )

        if self.role == "traveler":
            if self.travel_date is not None:
                raise ValueError(
                    "Travel date should not be provided for traveler journeys."
                )

            if self.travel_time is not None:
                raise ValueError(
                    "Travel time should not be provided for traveler journeys."
                )

        return self


class TripRequestResponse(BaseModel):
    message: str

    status: str

    user_id: int

    role: str

    source: str

    destination: str

    latitude: float

    longitude: float

    travel_date: date | None = None

    travel_time: time | None = None

    traveler_report: TravelerReport | None = None

    trip_id: int | None = None

    report_id: int | None = None

    report_normalized_data: dict | None = None

    extraction_confidence: float | None = None