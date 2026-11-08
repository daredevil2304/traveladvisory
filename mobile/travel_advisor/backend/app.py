from fastapi import FastAPI

from config import settings
from database import Base, engine
from models import CommuteCheckLog, CommuteHabit, User
from models.travel_report import TravelReport

from routes import auth_router, trip_router
from routes.chatbot_routes import router as chatbot_router
from routes.community_routes import router as community_router
from routes.notification_routes import router as notification_router
from routes.report_routes import router as report_router


# ================================================================
# DATABASE INITIALIZATION HELPER
# ================================================================

def init_db():
    try:
        Base.metadata.create_all(bind=engine)
        from sqlalchemy import text
        with engine.connect() as _migration_conn:
            is_sqlite = engine.dialect.name == "sqlite"
            sql_schedule = (
                "ALTER TABLE commute_habits ADD COLUMN schedule_type VARCHAR(20) DEFAULT 'outbound';"
                if is_sqlite
                else "ALTER TABLE commute_habits ADD COLUMN IF NOT EXISTS schedule_type VARCHAR(20) DEFAULT 'outbound';"
            )
            sql_days = (
                "ALTER TABLE commute_habits ADD COLUMN travel_days VARCHAR(50) DEFAULT 'Daily';"
                if is_sqlite
                else "ALTER TABLE commute_habits ADD COLUMN IF NOT EXISTS travel_days VARCHAR(50) DEFAULT 'Daily';"
            )
            try:
                _migration_conn.execute(text(sql_schedule))
            except Exception:
                pass
            try:
                _migration_conn.execute(text(sql_days))
            except Exception:
                pass
            _migration_conn.commit()
    except Exception as _migration_err:
        print(f"Database initialization/migration notice: {_migration_err}")



# ================================================================
# FASTAPI APPLICATION
# ================================================================

app = FastAPI(
    title=settings.app_name,
)


# ================================================================
# ROUTES
# ================================================================

app.include_router(
    auth_router,
)

app.include_router(
    trip_router,
)

app.include_router(
    chatbot_router,
)

app.include_router(
    community_router,
)

app.include_router(
    report_router,
)

app.include_router(
    notification_router,
)


# ================================================================
# BACKGROUND COMMUTE ALERT SCHEDULER
# ================================================================

import asyncio
from database import SessionLocal
from services.timezone_service import get_ist_now
from services.commute_notification_service import commute_notification_service


async def _commute_alert_worker():
    """
    Background worker running every 60 seconds.
    Evaluates enabled commute habits matching current IST time and active travel days,
    generates proactive corridor alerts, and logs checks automatically.
    """
    while True:
        try:
            now = get_ist_now()
            current_time_str = now.strftime("%H:%M")
            with SessionLocal() as db:
                habits = (
                    db.query(CommuteHabit)
                    .filter(CommuteHabit.is_enabled == True)
                    .all()
                )
                for habit in habits:
                    alert_time = habit.alert_time.strip()
                    # Normalise to HH:MM if in 12h format e.g. "07:45 AM"
                    if "AM" in alert_time.upper() or "PM" in alert_time.upper():
                        parts = alert_time.replace("AM", "").replace("PM", "").strip().split(":")
                        if len(parts) == 2:
                            try:
                                h = int(parts[0])
                                m = int(parts[1])
                                if "PM" in alert_time.upper() and h < 12:
                                    h += 12
                                elif "AM" in alert_time.upper() and h == 12:
                                    h = 0
                                alert_time = f"{h:02d}:{m:02d}"
                            except ValueError:
                                pass

                    if alert_time[:5] == current_time_str:
                        if commute_notification_service.is_scheduled_current_day(habit.travel_days, now):
                            try:
                                commute_notification_service.generate_commute_alert(
                                    db=db,
                                    user_id=habit.user_id,
                                    source=habit.source_name,
                                    destination=habit.destination_name,
                                )
                            except Exception:
                                pass
        except Exception:
            pass
        await asyncio.sleep(60)


@app.on_event("startup")
async def startup_event():
    init_db()
    asyncio.create_task(_commute_alert_worker())
    # Prediction models load lazily into cache on first trip request to prevent startup OOM on 512MB free tier
    pass


# ================================================================
# HEALTH CHECK
# ================================================================

@app.get("/")
def root():
    return {
        "message": "Mumbai-Pune Travel Intelligence API is running."
    }


@app.get("/health")
def health():
    return {
        "status": "healthy",
    }


# ================================================================
# LOCAL DEVELOPMENT
# ================================================================

if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        "app:app",
        host="0.0.0.0",
        port=8000,
        reload=True,
    )