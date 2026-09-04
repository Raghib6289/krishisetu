import json
import logging
from datetime import datetime
from typing import Dict, List, Any, Optional
from fastapi import WebSocket, WebSocketDisconnect

logger = logging.getLogger("inventory_ws")

class InventoryConnectionManager:
    """
    Manages WebSocket subscribers listening to real-time marketplace inventory events.
    Connected clients (Buyers, Farmers, Admins) receive immediate broadcast events when:
    - A farmer lists a new crop ('CROP_ADDED')
    - A consumer places an order ('STOCK_UPDATED', 'OUT_OF_STOCK')
    - A farmer adjusts price or replenishes stock ('RESTOCKED', 'CROP_UPDATED')
    - A listing is deleted ('CROP_DELETED')
    """
    def __init__(self):
        self.active_connections: List[WebSocket] = []
        # In-memory recent events cache for instant synchronization upon connection
        self.recent_events: List[Dict[str, Any]] = []

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.append(websocket)
        logger.info(f"New client connected to /ws/inventory. Total subscribers: {len(self.active_connections)}")

        # Send initial welcome and recent event history
        try:
            welcome_payload = {
                "type": "CONNECTION_ESTABLISHED",
                "message": "Connected to KrishiSetu Real-Time Live Inventory Hub",
                "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
                "subscribers_count": len(self.active_connections),
                "recent_events": self.recent_events[-5:]
            }
            await websocket.send_text(json.dumps(welcome_payload))
        except Exception as e:
            logger.error(f"Error sending welcome payload: {e}")

    def disconnect(self, websocket: WebSocket):
        if websocket in self.active_connections:
            self.active_connections.remove(websocket)
        logger.info(f"Client disconnected from /ws/inventory. Remaining subscribers: {len(self.active_connections)}")

    async def broadcast(self, message: Dict[str, Any]):
        """Broadcasts an inventory event to all active WebSocket connections."""
        if "timestamp" not in message:
            message["timestamp"] = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

        # Cache event
        self.recent_events.append(message)
        if len(self.recent_events) > 50:
            self.recent_events = self.recent_events[-50:]

        serialized = json.dumps(message)
        disconnected = []

        for conn in self.active_connections:
            try:
                await conn.send_text(serialized)
            except Exception:
                disconnected.append(conn)

        for dead_conn in disconnected:
            self.disconnect(dead_conn)

    async def broadcast_crop_added(self, crop: Dict[str, Any]):
        await self.broadcast({
            "type": "CROP_ADDED",
            "crop": crop,
            "message": f"New produce listed: {crop.get('crop_name')} ({crop.get('quantity_quintals')} Quintals)"
        })

    async def broadcast_stock_updated(
        self,
        crop_id: str,
        crop_name: str,
        farmer_name: str,
        new_quantity_quintals: float,
        status: str,
        purchased_kg: float,
        buyer_name: str,
        order_id: Optional[str] = None
    ):
        await self.broadcast({
            "type": "STOCK_UPDATED",
            "crop_id": crop_id,
            "crop_name": crop_name,
            "farmer_name": farmer_name,
            "new_quantity_quintals": round(new_quantity_quintals, 2),
            "status": status,
            "purchased_kg": round(purchased_kg, 1),
            "buyer_name": buyer_name,
            "order_id": order_id,
            "is_out_of_stock": (new_quantity_quintals <= 0.001 or status == "OUT_OF_STOCK"),
            "message": f"{buyer_name} purchased {purchased_kg} kg of {crop_name}. Remaining: {round(new_quantity_quintals, 2)} Qtl"
        })

    async def broadcast_crop_updated(self, crop: Dict[str, Any], update_type: str = "CROP_UPDATED"):
        await self.broadcast({
            "type": update_type,
            "crop": crop,
            "crop_id": crop.get("id"),
            "new_quantity_quintals": crop.get("quantity_quintals"),
            "status": crop.get("status"),
            "message": f"Listing updated for {crop.get('crop_name')} ({crop.get('quantity_quintals')} Qtl @ ₹{crop.get('price_per_kg')}/kg)"
        })

    async def broadcast_crop_deleted(self, crop_id: str):
        await self.broadcast({
            "type": "CROP_DELETED",
            "crop_id": crop_id,
            "message": f"Listing {crop_id} removed by farmer"
        })

inventory_manager = InventoryConnectionManager()
