from __future__ import annotations

import logging
from sqlalchemy import create_engine, text
from sqlalchemy.orm import DeclarativeBase, sessionmaker

from config import settings

logger = logging.getLogger(__name__)


def _create_resilient_engine():
    db_url = settings.database_url or ""
    if db_url.startswith("postgres"):
        try:
            logger.info("Attempting connection to PostgreSQL database...")
            # Use a strict 3-second connect timeout so bad host/DNS failure won't hang the server
            conn_args = {"connect_timeout": 3} if "postgresql" in db_url else {}
            test_engine = create_engine(
                db_url,
                pool_pre_ping=True,
                connect_args=conn_args,
            )
            with test_engine.connect() as conn:
                conn.execute(text("SELECT 1;"))
            logger.info("Successfully connected to PostgreSQL database.")
            return test_engine
        except Exception as exc:
            logger.warning(
                f"PostgreSQL connection failed ({exc}). Gracefully falling back to local SQLite database."
            )

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
