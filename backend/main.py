import os
import sys

# Ensure root directory (D:\krishisetu) is in sys.path and PYTHONPATH for Windows multiprocessing reloader
_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if _ROOT not in sys.path:
    sys.path.insert(0, _ROOT)
if "PYTHONPATH" not in os.environ or _ROOT not in os.environ.get("PYTHONPATH", ""):
    os.environ["PYTHONPATH"] = _ROOT + (os.pathsep + os.environ["PYTHONPATH"] if "PYTHONPATH" in os.environ else "")

import json
import logging
from contextlib import asynccontextmanager
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.responses import HTMLResponse
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware
from backend.database import init_db, get_db_info
from backend.routers import auth, crops, orders, forecast, routes, upload
from backend.services.tracking_ws import tracking_manager
from backend.services.inventory_ws import inventory_manager
from backend.demo_ui import DEMO_HTML

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("krishisetu_main")

UPLOAD_DIR = os.path.join(os.path.dirname(__file__), "uploads")
os.makedirs(UPLOAD_DIR, exist_ok=True)

@asynccontextmanager
async def lifespan(app: FastAPI):
    db_info = get_db_info()
    logger.info(f"Initializing KrishiSetu database [{db_info['engine']} via {db_info['provider']}]...")
    init_db()
    logger.info(f"Database [{db_info['engine']}] initialized successfully.")
    yield

app = FastAPI(
    title="KrishiSetu AI & Logistics Engine API",
    description="Backend microservices for SIH 2026 Problem 26033: Direct agricultural marketplace with AI demand forecasting and OR-Tools route optimization.",
    version="1.0.0",
    lifespan=lifespan
)

# Enable CORS for Flutter mobile, web, and desktop clients
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Mount Static uploads directory
app.mount("/uploads", StaticFiles(directory=UPLOAD_DIR), name="uploads")

# Register REST Routers
app.include_router(auth.router)
app.include_router(crops.router)
app.include_router(orders.router)
app.include_router(forecast.router)
app.include_router(routes.router)
app.include_router(upload.router)

@app.get("/")
def health_check():
    return {
        "status": "online",
        "service": "KrishiSetu AI & Logistics Backend",
        "version": "1.0.0",
        "database": get_db_info(),
        "auth_methods": ["mobile_otp", "jwt_token"],
        "endpoints": {
            "send_otp": "/api/auth/send-otp",
            "verify_otp": "/api/auth/verify-otp",
            "crops": "/api/crops",
            "forecast": "/api/forecast?crop=tomato&days=7",
            "route_optimization": "/api/routes/optimize",
            "upload_image": "/api/upload",
            "live_websocket": "/ws/tracking/{order_id}",
            "live_inventory_websocket": "/ws/inventory"
        }
    }

@app.get("/demo", response_class=HTMLResponse)
def get_interactive_demo():
    """Renders full interactive UI for Farmer, Buyer, and Driver with live AI predictions and WebSockets."""
    return DEMO_HTML

@app.websocket("/ws/inventory")
async def websocket_inventory_endpoint(websocket: WebSocket):
    """
    Real-time multi-tenant marketplace inventory broadcast channel:
    - Broadcasts CROP_ADDED when farmers list produce.
    - Broadcasts STOCK_UPDATED & OUT_OF_STOCK live when buyers purchase produce.
    - Broadcasts CROP_UPDATED & RESTOCKED when farmers adjust prices/stock.
    """
    await inventory_manager.connect(websocket)
    try:
        while True:
            data_text = await websocket.receive_text()
            try:
                data = json.loads(data_text)
                # Allow bidirectional messages such as ping or client queries
                if data.get("action") == "ping":
                    await websocket.send_text(json.dumps({"type": "PONG", "timestamp": data.get("timestamp")}))
            except json.JSONDecodeError:
                pass
    except WebSocketDisconnect:
        inventory_manager.disconnect(websocket)
    except Exception as e:
        logger.error(f"WebSocket error in /ws/inventory: {e}")
        inventory_manager.disconnect(websocket)

@app.websocket("/ws/tracking/{order_id}")
async def websocket_tracking_endpoint(websocket: WebSocket, order_id: str):
    """
    Bi-directional live tracking channel:
    - Drivers stream continuous GPS telemetry (lat, lng, speed, heading, status).
    - Buyers receive real-time vehicle movement updates to update map markers dynamically.
    """
    await tracking_manager.connect(order_id, websocket)
    try:
        while True:
            data_text = await websocket.receive_text()
            try:
                data = json.loads(data_text)
                # Broadcast incoming telemetry to all listeners on this order channel
                await tracking_manager.broadcast_telemetry(order_id, data)
            except json.JSONDecodeError:
                logger.warning(f"Received non-JSON telemetry on order {order_id}: {data_text}")
    except WebSocketDisconnect:
        tracking_manager.disconnect(order_id, websocket)
    except Exception as e:
        logger.error(f"WebSocket error on order {order_id}: {e}")
        tracking_manager.disconnect(order_id, websocket)

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("backend.main:app", host="0.0.0.0", port=8000, reload=True)
