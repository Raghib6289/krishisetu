import asyncio
import json
import uvicorn
import requests
from threading import Thread
import time
from backend.main import app

def run_server():
    uvicorn.run(app, host="127.0.0.1", port=8089, log_level="warning")

def test_api():
    base_url = "http://127.0.0.1:8089"
    time.sleep(2)
    
    print("\n--- 1. Testing Health Check ---")
    r = requests.get(f"{base_url}/")
    print("Health response:", r.json())
    assert r.status_code == 200

    print("\n--- 2. Testing Unified Auth (Farmer Login) ---")
    login_payload = {"email": "farmer@krishisetu.com", "password": "pass123"}
    r = requests.post(f"{base_url}/api/auth/login", json=login_payload)
    print("Login status:", r.status_code)
    auth_data = r.json()
    print("Logged in as user_type:", auth_data.get("user_type"), "Name:", auth_data.get("name"))
    assert auth_data.get("user_type") == "farmer"

    print("\n--- 3. Testing Crop Listings ---")
    r = requests.get(f"{base_url}/api/crops")
    crops = r.json()
    print(f"Retrieved {len(crops)} crops. First crop: {crops[0]['crop_name']} @ Rs.{crops[0]['price_per_kg']}/kg")
    assert len(crops) > 0

    print("\n--- 4. Testing AI Demand & Price Forecasting (ARIMA) ---")
    r = requests.get(f"{base_url}/api/forecast?crop=tomato&days=7")
    forecast_data = r.json()
    print("Crop:", forecast_data["crop"], "Mandi:", forecast_data["mandi"])
    print("Trend:", forecast_data["trend_summary"])
    print("Best time to sell:", forecast_data["best_time_to_sell"])
    print("7-day forecast points:", len(forecast_data["forecast"]))
    print("First forecast day price:", forecast_data["forecast"][0]["price"])
    assert len(forecast_data["forecast"]) == 7

    print("\n--- 5. Testing Google OR-Tools Route Optimization (VRP) ---")
    sample_r = requests.get(f"{base_url}/api/routes/sample-stops")
    sample = sample_r.json()
    opt_payload = {
        "depot": sample["depot"],
        "stops": sample["stops"],
        "vehicle_capacity": 500,
        "num_vehicles": 1
    }
    r = requests.post(f"{base_url}/api/routes/optimize", json=opt_payload)
    opt_result = r.json()
    print("Optimization method:", opt_result["optimization_method"])
    print(f"Total distance: {opt_result['total_distance_km']} km, Estimated time: {opt_result['total_time_mins']} mins")
    route = opt_result["routes"][0]
    print(f"Stops sequence ({len(route['stops_sequence'])} stops):")
    for s in route["stops_sequence"]:
        print(f"  -> [{s['stop_type'].upper()}] {s['name']} (at {s['cumulative_distance_km']} km, +{s['estimated_arrival_mins']}m)")
    print(f"Generated {len(route['polyline_coordinates'])} polyline waypoints for map rendering.")
    assert len(route["stops_sequence"]) > 0

    print("\n[ALL BACKEND SERVICES TESTED & VERIFIED SUCCESSFULLY!]")

if __name__ == "__main__":
    server_thread = Thread(target=run_server, daemon=True)
    server_thread.start()
    test_api()
