from services.traveler_report_service import (
    TravelerReportService,
)


service = TravelerReportService()


def test_coordinate_validation():
    service._validate_coordinates(
        latitude=18.7877,
        longitude=73.3438,
    )


def test_invalid_latitude():
    try:
        service._validate_coordinates(
            latitude=100,
            longitude=73.3438,
        )
        assert False, "Expected ValueError"
    except ValueError:
        pass


def test_invalid_longitude():
    try:
        service._validate_coordinates(
            latitude=18.7877,
            longitude=200,
        )
        assert False, "Expected ValueError"
    except ValueError:
        pass


def test_empty_message():
    try:
        service._validate_raw_message("")
        assert False, "Expected ValueError"
    except ValueError:
        pass


def test_valid_route_region():
    assert (
        service._validate_route_region("r4")
        == "R4"
    )


def test_invalid_route_region():
    try:
        service._validate_route_region("R99")
        assert False, "Expected ValueError"
    except ValueError:
        pass


def test_confidence():
    assert (
        service._validate_confidence(0.91)
        == 0.91
    )


def test_invalid_confidence():
    try:
        service._validate_confidence(1.5)
        assert False, "Expected ValueError"
    except ValueError:
        pass