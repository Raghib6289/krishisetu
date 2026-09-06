import asyncio
import json
import time
import requests
import uvicorn
import websockets
from threading import Thread
from backend.main import app

PORT = 8092
BASE_HTTP = f"http://127.0.0.1:{PORT}"
BASE_WS = f"ws://127.0.0.1:{PORT}"

def run_server():
    uvicorn.run(app, host="127.0.0.1", port=PORT, log_level="error")

async def test_real_time_inventory():
    for attempt in range(15):
        try:
            r = requests.get(f"{BASE_HTTP}/", timeout=2)
            if r.status_code == 200:
                break
        except Exception:
            time.sleep(1)
    uri = f"{BASE_WS}/ws/inventory"

    print("\n--- 1. Connecting Consumer WebSocket to /ws/inventory ---")
    async with websockets.connect(uri) as ws_consumer:
        welcome_raw = await ws_consumer.recv()
        welcome = json.loads(welcome_raw)
        print("Connected! Received welcome:", welcome.get("type"), welcome.get("message"))
        assert welcome["type"] == "CONNECTION_ESTABLISHED"

        # 2. Farmer posts a new crop listing via REST API
        print("\n--- 2. Farmer Adding Produce Listing via REST API ---")
        new_crop_payload = {
            "farmer_id": "usr_farmer_101",
            "farmer_name": "Ramesh Patil",
            "farmer_phone": "+91 98765 43210",
            "crop_name": "Hydroponic Crisp Lettuce",
            "category": "Vegetables",
            "quantity_quintals": 10.0,
            "price_per_kg": 45.0,
            "grade": "A+",
            "harvest_date": "2026-09-04",
            "location": "Dindori Farm Cluster, Nashik",
            "image_url": "https://images.unsplash.com/photo-1540420773420-3366772f4999?w=600",
            "mandi_price_comparison": 38.0,
            "status": "AVAILABLE"
        }

        resp = requests.post(f"{BASE_HTTP}/api/crops", json=new_crop_payload)
        assert resp.status_code == 200, f"Error: {resp.text}"
        crop_data = resp.json()
        crop_id = crop_data["id"]
        print(f"Crop created with ID: {crop_id}")

        # Verify WebSocket broadcast received by consumer
        event_raw = await asyncio.wait_for(ws_consumer.recv(), timeout=5.0)
        event = json.loads(event_raw)
        print("Consumer received WebSocket broadcast:")
        print(f"  Type: {event.get('type')}, Crop: {event.get('crop', {}).get('crop_name')}")
        assert event["type"] == "CROP_ADDED"
        assert event["crop"]["id"] == crop_id

        # 3. Buyer purchases 500 kg (5 quintals) of the crop
        print("\n--- 3. Buyer Placing Order for 500 kg (5 Quintals) ---")
        order_payload = {
            "buyer_id": "usr_buyer_202",
            "buyer_name": "Reliance Fresh Retail Hub",
            "buyer_phone": "+91 98220 11223",
            "delivery_address": "Vashi APMC Market, Navi Mumbai",
            "delivery_lat": 19.0760,
            "delivery_lng": 72.9980,
            "items": [
                {
                    "listing_id": crop_id,
                    "crop_name": "Hydroponic Crisp Lettuce",
                    "farmer_name": "Ramesh Patil",
                    "quantity_kg": 500.0,
                    "price_per_kg": 45.0
                }
            ],
            "payment_method": "Razorpay Instant",
            "payment_id": "pay_test_ws_001"
        }

        resp_order = requests.post(f"{BASE_HTTP}/api/orders", json=order_payload)
        assert resp_order.status_code == 200
        print("Order placed successfully!")

        # Verify WebSocket stock update broadcast
        stock_event_raw = await asyncio.wait_for(ws_consumer.recv(), timeout=5.0)
        stock_event = json.loads(stock_event_raw)
        print("Consumer received Real-Time Stock Update:")
        print(f"  Type: {stock_event.get('type')}, Remaining: {stock_event.get('new_quantity_quintals')} Qtl, Status: {stock_event.get('status')}")
        assert stock_event["type"] == "STOCK_UPDATED"
        assert stock_event["crop_id"] == crop_id
        assert abs(stock_event["new_quantity_quintals"] - 5.0) < 0.1

        # 4. Buyer purchases the remaining 500 kg (5 quintals) -> Should trigger OUT_OF_STOCK
        print("\n--- 4. Buyer Purchasing Remaining Stock to Exhaust Listing ---")
        order_payload_2 = {
            "buyer_id": "usr_buyer_202",
            "buyer_name": "Reliance Fresh Retail Hub",
            "buyer_phone": "+91 98220 11223",
            "delivery_address": "Vashi APMC Market, Navi Mumbai",
            "delivery_lat": 19.0760,
            "delivery_lng": 72.9980,
            "items": [
                {
                    "listing_id": crop_id,
                    "crop_name": "Hydroponic Crisp Lettuce",
                    "farmer_name": "Ramesh Patil",
                    "quantity_kg": 500.0,
                    "price_per_kg": 45.0
                }
            ],
            "payment_method": "Razorpay Instant",
            "payment_id": "pay_test_ws_002"
        }

        resp_order_2 = requests.post(f"{BASE_HTTP}/api/orders", json=order_payload_2)
        assert resp_order_2.status_code == 200

        # Verify WebSocket broadcast reflects OUT_OF_STOCK
        depleted_raw = await asyncio.wait_for(ws_consumer.recv(), timeout=5.0)
        depleted_event = json.loads(depleted_raw)
        print("Consumer received Out of Stock Event:")
        print(f"  Remaining: {depleted_event.get('new_quantity_quintals')} Qtl, Status: {depleted_event.get('status')}, OutOfStock: {depleted_event.get('is_out_of_stock')}")
        assert depleted_event["type"] == "STOCK_UPDATED"
        assert depleted_event["new_quantity_quintals"] == 0.0
        assert depleted_event["status"] == "OUT_OF_STOCK"
        assert depleted_event["is_out_of_stock"] is True

        # 5. Farmer 1-Tap Quick Restock: add 20 Quintals
        print("\n--- 5. Farmer 1-Tap Quick Restock (+20 Quintals) ---")
        restock_payload = {"action": "add", "amount_quintals": 20.0}
        resp_restock = requests.patch(f"{BASE_HTTP}/api/crops/{crop_id}/quick-stock", json=restock_payload)
        assert resp_restock.status_code == 200
        print("Restocked successfully! New status in DB:", resp_restock.json()["status"])

        restock_raw = await asyncio.wait_for(ws_consumer.recv(), timeout=5.0)
        restock_event = json.loads(restock_raw)
        print("Consumer received RESTOCKED event:")
        print(f"  Type: {restock_event.get('type')}, New Qty: {restock_event.get('new_quantity_quintals')} Qtl, Status: {restock_event.get('status')}")
        assert restock_event["type"] == "RESTOCKED"
        assert restock_event["new_quantity_quintals"] == 20.0
        assert restock_event["status"] == "AVAILABLE"

        # 6. Test Farmer Analytics Endpoint
        print("\n--- 6. Testing Farmer Analytics API ---")
        resp_analytics = requests.get(f"{BASE_HTTP}/api/crops/farmer/usr_farmer_101/analytics")
        assert resp_analytics.status_code == 200
        analytics = resp_analytics.json()
        print(f"Farmer Analytics:")
        print(f"  Total Crops: {analytics['total_crops']}, Total Qtl Available: {analytics['total_quintals_available']}")
        print(f"  Total Inventory Valuation: Rs.{analytics['total_inventory_valuation_inr']:,.2f}")
        print(f"  Mandi Arbitrage Benefit: Rs.{analytics['estimated_mandi_arbitrage_gain']:,.2f}")
        print(f"  Total Sales Revenue: Rs.{analytics['total_sales_revenue_inr']:,.2f}")

        # Clean up created test crop
        requests.delete(f"{BASE_HTTP}/api/crops/{crop_id}")
        print("\n[REAL-TIME INVENTORY WEBSOCKET MANAGEMENT TEST COMPLETED SUCCESSFULLY!]")

if __name__ == "__main__":
    server_thread = Thread(target=run_server, daemon=True)
    server_thread.start()
    asyncio.run(test_real_time_inventory())
