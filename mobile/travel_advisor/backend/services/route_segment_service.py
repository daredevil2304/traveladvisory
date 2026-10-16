from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class RoutePoint:
    name: str
    order: int


@dataclass(frozen=True)
class RouteSegment:
    region: str
    start: str
    end: str


# ================================================================
# ROUTE POINTS
# ================================================================

ROUTE_POINTS: tuple[RoutePoint, ...] = (
    RoutePoint("Mumbai", 1),
    RoutePoint("Panvel", 2),
    RoutePoint("Khalapur", 3),
    RoutePoint("Khopoli", 4),
    RoutePoint("Khandala", 5),
    RoutePoint("Lonavala", 6),
    RoutePoint("Kamshet", 7),
    RoutePoint("Pune", 8),
)


# ================================================================
# ROUTE SEGMENTS
# ================================================================

ROUTE_SEGMENTS: tuple[RouteSegment, ...] = (
    RouteSegment("R1", "Mumbai", "Panvel"),
    RouteSegment("R2", "Panvel", "Khalapur"),
    RouteSegment("R3", "Khalapur", "Khopoli"),
    RouteSegment("R4", "Khopoli", "Khandala"),
    RouteSegment("R5", "Khandala", "Lonavala"),
    RouteSegment("R6", "Lonavala", "Kamshet"),
    RouteSegment("R7", "Kamshet", "Pune"),
)


# ================================================================
# ROUTE POINT COORDINATES
# ================================================================
#
# These are representative road-route coordinates.
# They are NOT ERA5 grid coordinates.
#
# ERA5 grid mapping remains a separate responsibility.
# ================================================================

ROUTE_POINT_COORDINATES: dict[str, tuple[float, float]] = {
    "Mumbai": (19.0760, 72.8777),
    "Panvel": (18.9888, 73.1101),
    "Khalapur": (18.8167, 73.2667),
    "Khopoli": (18.7877, 73.3438),
    "Khandala": (18.7607, 73.3768),
    "Lonavala": (18.7546, 73.4062),
    "Kamshet": (18.7629, 73.5576),
    "Pune": (18.5204, 73.8567),
}


# ================================================================
# LOCATION ALIASES
# ================================================================

LOCATION_ALIASES: dict[str, str] = {
    "sion": "Mumbai",
    "sion mumbai": "Mumbai",
    "mumbai": "Mumbai",
    "panvel": "Panvel",
    "khalapur": "Khalapur",
    "khopoli": "Khopoli",
    "khandala": "Khandala",
    "lonavala": "Lonavala",
    "kamshet": "Kamshet",
    "pune": "Pune",
}


# ================================================================
# LOCATION NORMALIZATION
# ================================================================

def normalize_location(location: str) -> str:
    """
    Normalize a user-facing route location to the canonical
    Mumbai–Pune route point name.
    """

    if not isinstance(location, str):
        raise ValueError(
            "Location must be a string."
        )

    normalized = (
        location
        .strip()
        .lower()
        .replace("-", " ")
        .replace("_", " ")
    )

    normalized = " ".join(
        normalized.split()
    )

    if normalized in LOCATION_ALIASES:
        return LOCATION_ALIASES[normalized]

    for canonical_name in (
        point.name
        for point in ROUTE_POINTS
    ):
        if normalized == canonical_name.lower():
            return canonical_name

    raise ValueError(
        f"Unknown Mumbai–Pune route location: {location}"
    )


# ================================================================
# ROUTE POINT LOOKUP
# ================================================================

def get_route_point_order(
    location: str,
) -> int:
    """
    Return the ordered position of a route point.
    """

    canonical_name = normalize_location(
        location
    )

    for point in ROUTE_POINTS:
        if point.name == canonical_name:
            return point.order

    raise ValueError(
        f"Route point not found: {location}"
    )


# ================================================================
# ROUTE SEGMENT LOOKUP
# ================================================================

def get_segment_details(
    region: str,
) -> RouteSegment:
    """
    Return complete metadata for R1–R7.
    """

    normalized_region = (
        region.strip().upper()
        if isinstance(region, str)
        else ""
    )

    for segment in ROUTE_SEGMENTS:
        if segment.region == normalized_region:
            return segment

    raise ValueError(
        f"Unknown route region: {region}"
    )


# ================================================================
# REGION BETWEEN TWO POINTS
# ================================================================

def get_region_between(
    start: str,
    end: str,
) -> str:
    """
    Return the route region directly connecting two
    consecutive route points.
    """

    start_name = normalize_location(start)
    end_name = normalize_location(end)

    for segment in ROUTE_SEGMENTS:
        if (
            segment.start == start_name
            and segment.end == end_name
        ):
            return segment.region

    raise ValueError(
        f"No direct route segment exists between "
        f"{start_name} and {end_name}."
    )


# ================================================================
# RESOLVE COMPLETE ROUTE
# ================================================================

def resolve_route_segments(
    source: str,
    destination: str,
) -> list[str]:
    """
    Resolve every route segment between source and destination.

    Direction is preserved.

    Examples:

        Mumbai → Pune
        R1, R2, R3, R4, R5, R6, R7

        Khopoli → Pune
        R4, R5, R6, R7

        Lonavala → Panvel
        R5, R4, R3, R2
    """

    source_name = normalize_location(source)
    destination_name = normalize_location(destination)

    source_order = get_route_point_order(
        source_name
    )

    destination_order = get_route_point_order(
        destination_name
    )

    if source_order == destination_order:
        return []

    segments: list[str] = []

    if source_order < destination_order:
        for index in range(
            source_order,
            destination_order,
        ):
            start_point = ROUTE_POINTS[index - 1]
            end_point = ROUTE_POINTS[index]

            region = get_region_between(
                start_point.name,
                end_point.name,
            )

            segments.append(region)

    else:
        for index in range(
            source_order,
            destination_order,
            -1,
        ):
            start_point = ROUTE_POINTS[index - 1]
            end_point = ROUTE_POINTS[index - 2]

            region = get_region_between(
                end_point.name,
                start_point.name,
            )

            # get_region_between expects the canonical
            # forward route direction. Therefore, for a
            # reverse journey we resolve the corresponding
            # forward segment manually.
            for segment in ROUTE_SEGMENTS:
                if (
                    segment.start == end_point.name
                    and segment.end == start_point.name
                ):
                    region = segment.region
                    break

            segments.append(region)

    return segments


# ================================================================
# ROUTE SUMMARY
# ================================================================

def get_route_summary(
    source: str,
    destination: str,
) -> dict:
    """
    Return a structured summary of the journey.
    """

    source_name = normalize_location(source)
    destination_name = normalize_location(destination)

    segments = resolve_route_segments(
        source_name,
        destination_name,
    )

    segment_details = [
        get_segment_details(region)
        for region in segments
    ]

    return {
        "source": source_name,
        "destination": destination_name,
        "segments": segments,
        "segment_details": [
            {
                "region": segment.region,
                "start": segment.start,
                "end": segment.end,
            }
            for segment in segment_details
        ],
        "segment_count": len(segments),
        "direction": (
            "forward"
            if get_route_point_order(source_name)
            <= get_route_point_order(destination_name)
            else "reverse"
        ),
    }


# ================================================================
# ROUTE POINT COORDINATES
# ================================================================

def get_route_point_coordinates(
    point_name: str,
) -> tuple[float, float]:
    """
    Return latitude and longitude for a canonical route point.
    """

    canonical_name = normalize_location(
        point_name
    )

    coordinates = ROUTE_POINT_COORDINATES.get(
        canonical_name
    )

    if coordinates is None:
        raise ValueError(
            f"No coordinates configured for route point: "
            f"{point_name}"
        )

    return coordinates


# ================================================================
# SEGMENT REPRESENTATIVE COORDINATES
# ================================================================

def get_segment_coordinates(
    region: str,
) -> tuple[float, float]:
    """
    Return a representative coordinate for a route segment.

    The current implementation uses the geographic midpoint
    between the segment's two canonical route points.

    These coordinates are used for location-specific weather
    lookup. They are not ERA5 coordinates.
    """

    segment = get_segment_details(
        region
    )

    start_latitude, start_longitude = (
        get_route_point_coordinates(
            segment.start
        )
    )

    end_latitude, end_longitude = (
        get_route_point_coordinates(
            segment.end
        )
    )

    midpoint_latitude = (
        start_latitude + end_latitude
    ) / 2

    midpoint_longitude = (
        start_longitude + end_longitude
    ) / 2

    return (
        round(midpoint_latitude, 6),
        round(midpoint_longitude, 6),
    )