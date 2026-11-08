from __future__ import annotations

import logging
import socket
import urllib.parse
from concurrent.futures import ThreadPoolExecutor, TimeoutError
from sqlalchemy import create_engine, text
from sqlalchemy.orm import DeclarativeBase, sessionmaker

from config import settings

logger = logging.getLogger(__name__)


def _is_host_resolvable(host: str, port: int = 5432, timeout: float = 1.5) -> bool:
    """
    Safely probes DNS resolution within a strict timeout to prevent
    glibc getaddrinfo from hanging the uvicorn worker process.
    """
    def _resolve():
        return socket.getaddrinfo(host, port, proto=socket.IPPROTO_TCP)

    try:
        with ThreadPoolExecutor(max_workers=1) as executor:
            future = executor.submit(_resolve)
            future.result(timeout=timeout)
            return True
    except (TimeoutError, Exception) as exc:
        logger.warning(f"Database host '{host}' DNS resolution failed or timed out: {exc}")
        return False


def _create_resilient_engine():
    raw_url = (settings.database_url or "").strip()
    if raw_url.startswith("postgres"):
        db_url = raw_url
        if db_url.startswith("postgres://"):
            db_url = db_url.replace("postgres://", "postgresql://", 1)

        try:
            parsed = urllib.parse.urlparse(db_url)
            host = parsed.hostname
            port = parsed.port or 5432

            if host:
                if not _is_host_resolvable(host, port, timeout=1.5):
                    logger.warning(
                        f"PostgreSQL host '{host}' is unreachable via DNS. Falling back to SQLite."
                    )
                    return _sqlite_engine()

            logger.info("Attempting connection to PostgreSQL database...")
            test_engine = create_engine(
                db_url,
                pool_pre_ping=True,
                connect_args={"connect_timeout": 3},
            )
            with test_engine.connect() as conn:
                conn.execute(text("SELECT 1;"))
            logger.info("Successfully connected to PostgreSQL database.")
            return test_engine
        except Exception as exc:
            logger.warning(
                f"PostgreSQL connection failed ({exc}). Gracefully falling back to local SQLite database."
            )

    return _sqlite_engine()


def _sqlite_engine():
    logger.info("Using local SQLite database: sqlite:///./traveladvisory.db")
    return create_engine(
        "sqlite:///./traveladvisory.db",
        connect_args={"check_same_thread": False},
        pool_pre_ping=True,
    )


engine = _create_resilient_engine()

SessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=engine,
)


class Base(DeclarativeBase):
    pass


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
