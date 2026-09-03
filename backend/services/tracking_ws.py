import json
import logging
from typing import Dict, List
from fastapi import WebSocket, WebSocketDisconnect

logger = logging.getLogger("tracking_ws")

class ConnectionManager:
    def __init__(self):
        # order_id -> list of active WebSocket connections (e.g. buyer, driver, admin)
        self.active_connections: Dict[str, List[WebSocket]] = {}
        # Store last known location per order
        self.latest_telemetry: Dict[str, dict] = {}

    async def connect(self, order_id: str, websocket: WebSocket):
        await websocket.accept()
        if order_id not in self.active_connections:
            self.active_connections[order_id] = []
        self.active_connections[order_id].append(websocket)
        logger.info(f"Client connected to order {order_id}. Total connections: {len(self.active_connections[order_id])}")
        
        # If there's a cached latest telemetry for this order, immediately send to new listener
        if order_id in self.latest_telemetry:
            try:
                await websocket.send_text(json.dumps(self.latest_telemetry[order_id]))
            except Exception as e:
                logger.error(f"Error sending cached telemetry: {e}")

    def disconnect(self, order_id: str, websocket: WebSocket):
        if order_id in self.active_connections:
            if websocket in self.active_connections[order_id]:
                self.active_connections[order_id].remove(websocket)
            if len(self.active_connections[order_id]) == 0:
                del self.active_connections[order_id]
        logger.info(f"Client disconnected from order {order_id}")

    async def broadcast_telemetry(self, order_id: str, message: dict):
        self.latest_telemetry[order_id] = message
        if order_id in self.active_connections:
            serialized = json.dumps(message)
            disconnected = []
            for connection in self.active_connections[order_id]:
                try:
                    await connection.send_text(serialized)
                except Exception:
                    disconnected.append(connection)
            
            for dead_conn in disconnected:
                self.disconnect(order_id, dead_conn)

tracking_manager = ConnectionManager()
