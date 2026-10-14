from datetime import datetime, timedelta, timezone

# Indian Standard Time (IST): UTC+05:30
IST_OFFSET = timedelta(hours=5, minutes=30)
IST = timezone(IST_OFFSET, name="IST")


def get_ist_now() -> datetime:
    """
    Returns current datetime in Indian Standard Time (IST).
    Stored as naive datetime for database compatibility.
    """
    return datetime.now(IST).replace(tzinfo=None)


def get_ist_now_aware() -> datetime:
    """
    Returns current timezone-aware datetime in Indian Standard Time (IST).
    """
    return datetime.now(IST)


def format_ist_iso(dt: datetime | None = None) -> str:
    """
    Returns an ISO-8601 string in IST with timezone offset (+05:30).
    """
    if dt is None:
        return datetime.now(IST).isoformat()
    if dt.tzinfo is None:
        return dt.replace(tzinfo=IST).isoformat()
    return dt.astimezone(IST).isoformat()


def to_ist(dt: datetime) -> datetime:
    """
    Converts a datetime (whether UTC or naive) to IST.
    """
    if dt.tzinfo is None:
        return dt.replace(tzinfo=IST)
    return dt.astimezone(IST)
