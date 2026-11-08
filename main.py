"""
Alternative Root Entry Point (main:app) for Render / Production Deployments.
Bridges root execution seamlessly into mobile/travel_advisor/backend without circular imports.
"""
import importlib.util
import os
import sys
from pathlib import Path

# Add root directory and backend directory to sys.path
BASE_DIR = Path(__file__).resolve().parent
BACKEND_DIR = BASE_DIR / "mobile" / "travel_advisor" / "backend"

for d in (str(BASE_DIR), str(BACKEND_DIR)):
    if d not in sys.path:
        sys.path.insert(0, d)

# Ensure CWD is backend directory so local SQLite / model assets resolve accurately
os.chdir(BACKEND_DIR)

backend_app_path = BACKEND_DIR / "app.py"
spec = importlib.util.spec_from_file_location("backend_main_app", backend_app_path)
backend_module = importlib.util.module_from_spec(spec)
sys.modules["backend_main_app"] = backend_module
spec.loader.exec_module(backend_module)

# Expose FastAPI application instance for ASGI servers (Uvicorn / Gunicorn)
app = backend_module.app
init_db = backend_module.init_db

if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("PORT", 8000))
    uvicorn.run(app, host="0.0.0.0", port=port)
