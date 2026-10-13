from fastapi import FastAPI

from config import settings
from database import Base, engine
from models import User
from models.travel_report import TravelReport

from routes import auth_router, trip_router
from routes.chatbot_routes import router as chatbot_router
from routes.report_routes import router as report_router


# ================================================================
# DATABASE INITIALIZATION
# ================================================================

Base.metadata.create_all(bind=engine)


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
    report_router,
)


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