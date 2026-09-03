import asyncio
import json
import websockets
import uvicorn
from threading import Thread
import time
from backend.main import app

def run_server():
    uvicorn.run(app, host="127.0.0.1", port=8091, log_level="error")

async def test_live_tracking():
    time.sleep(2)
    uri = "ws://127.0.0.1:8091/ws/tracking/ord_9901"
    
    print("\n--- Connecting Buyer Listener to WebSocket ---")
    async with websockets.connect(uri) as buyer_ws:
        print("Buyer successfully connected to live tracking channel.")
        
        print("\n--- Connecting Driver Streamer to WebSocket ---")
        async with websockets.connect(uri) as driver_ws:
            telemetry = {
                "order_id": "ord_9901",
                "driver_id": "usr_driver_303",
                "driver_name": "Santosh Shinde",
                "latitude": 20.0124,
                "longitude": 73.8115,
                "speed_kmh": 42.5,
                "heading_deg": 185.0,
                "timestamp": "2026-09-03T20:25:00",
                "status": "IN_TRANSIT"
            }
            await driver_ws.send(json.dumps(telemetry))
            print("Driver transmitted GPS telemetry payload.")

        # Buyer should receive this broadcast
        received = await asyncio.wait_for(buyer_ws.recv(), timeout=5.0)
        data = json.loads(received)
        print("Buyer received real-time moving coordinate:")
        print(f"  Lat: {data['latitude']}, Lng: {data['longitude']}, Speed: {data['speed_kmh']} km/h, Status: {data['status']}")
        assert data["latitude"] == 20.0124
        print("[WEBSOCKET LIVE TRACKING CHANNEL VERIFIED SUCCESSFULLY!]")

if __name__ == "__main__":
    server_thread = Thread(target=run_server, daemon=True)
    server_thread.start()
    asyncio.run(test_live_tracking())
