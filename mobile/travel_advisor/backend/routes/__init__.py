from routes.auth_routes import router as auth_router
from routes.trip_routes import router as trip_router

__all__ = [
    "auth_router",
    "trip_router",
]