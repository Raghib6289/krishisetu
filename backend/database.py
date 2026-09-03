import os
import sqlite3
import json
import uuid
from datetime import datetime
from typing import List, Dict, Any, Optional

DB_FILE = os.path.join(os.path.dirname(__file__), "krishisetu.db")

def get_connection() -> sqlite3.Connection:
    conn = sqlite3.connect(DB_FILE, check_same_thread=False)
    conn.row_factory = sqlite3.Row
    return conn

def init_db():
    """Create all necessary tables and seed default realistic data if empty."""
    with get_connection() as conn:
        cursor = conn.cursor()

        # 1. Users Table
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS users (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                email TEXT UNIQUE NOT NULL,
                password_hash TEXT NOT NULL,
                salt TEXT NOT NULL,
                phone TEXT NOT NULL,
                user_type TEXT NOT NULL,
                location TEXT NOT NULL,
                created_at TEXT NOT NULL
            )
        """)

        # 2. Crops Table
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS crops (
                id TEXT PRIMARY KEY,
                farmer_id TEXT NOT NULL,
                farmer_name TEXT NOT NULL,
                farmer_phone TEXT NOT NULL,
                crop_name TEXT NOT NULL,
                category TEXT NOT NULL,
                quantity_quintals REAL NOT NULL,
                price_per_kg REAL NOT NULL,
                grade TEXT NOT NULL,
                harvest_date TEXT NOT NULL,
                location TEXT NOT NULL,
                image_url TEXT NOT NULL,
                mandi_price_comparison REAL NOT NULL,
                status TEXT NOT NULL DEFAULT 'AVAILABLE',
                created_at TEXT NOT NULL
            )
        """)

        # 3. Orders Table
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS orders (
                id TEXT PRIMARY KEY,
                buyer_id TEXT NOT NULL,
                buyer_name TEXT NOT NULL,
                buyer_phone TEXT NOT NULL,
                delivery_address TEXT NOT NULL,
                delivery_lat REAL NOT NULL,
                delivery_lng REAL NOT NULL,
                items_json TEXT NOT NULL,
                total_amount REAL NOT NULL,
                status TEXT NOT NULL DEFAULT 'ASSIGNED',
                driver_id TEXT,
                driver_name TEXT,
                payment_id TEXT,
                payment_status TEXT NOT NULL DEFAULT 'PAID',
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            )
        """)

        # 4. Tracking Pings Table
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS tracking_pings (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                order_id TEXT NOT NULL,
                driver_id TEXT NOT NULL,
                latitude REAL NOT NULL,
                longitude REAL NOT NULL,
                speed_kmh REAL NOT NULL,
                battery_pct REAL NOT NULL,
                timestamp TEXT NOT NULL
            )
        """)

        # 5. OTPs Table for Mobile Number Verification
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS otps (
                phone TEXT PRIMARY KEY,
                otp TEXT NOT NULL,
                user_type TEXT,
                name TEXT,
                created_at REAL NOT NULL,
                expires_at REAL NOT NULL
            )
        """)

        conn.commit()

        # Seed data if tables are empty
        cursor.execute("SELECT COUNT(*) FROM users")
        if cursor.fetchone()[0] == 0:
            _seed_default_data(cursor)
            conn.commit()

def _seed_default_data(cursor: sqlite3.Cursor):
    from backend.security import hash_password

    now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    # Default Users
    users = [
        ("usr_farmer_101", "Ramesh Patil", "farmer@krishisetu.com", "pass123", "+91 98765 43210", "farmer", "Dindori Farm Cluster, Nashik"),
        ("usr_buyer_202", "Reliance Fresh Retail Hub", "buyer@krishisetu.com", "pass123", "+91 98220 11223", "buyer", "Vashi APMC Market, Navi Mumbai"),
        ("usr_driver_303", "Santosh Shinde (Krishi Logistics)", "driver@krishisetu.com", "pass123", "+91 94231 88776", "driver", "Nashik Central Transport Yard"),
    ]

    for uid, name, email, password, phone, role, loc in users:
        p_hash, salt = hash_password(password)
        cursor.execute(
            "INSERT INTO users (id, name, email, password_hash, salt, phone, user_type, location, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
            (uid, name, email, p_hash, salt, phone, role, loc, now)
        )

    # Default Crops
    crops = [
        ("crop_101", "usr_farmer_101", "Ramesh Patil", "+91 98765 43210", "Hybrid Fresh Tomatoes", "Vegetables", 45.0, 24.0, "A+", "2026-09-02", "Dindori Farm Hub, Nashik", "https://images.unsplash.com/photo-1592924357228-91a4daadcfea?w=600&auto=format&fit=crop", 21.0, "AVAILABLE", now),
        ("crop_102", "usr_farmer_101", "Ramesh Patil", "+91 98765 43210", "Lasalgaon Red Onions", "Vegetables", 120.0, 19.5, "A", "2026-09-01", "Lasalgaon Agri Hub, Nashik", "https://images.unsplash.com/photo-1618512496248-a07fe83aa8cb?w=600&auto=format&fit=crop", 17.0, "AVAILABLE", now),
        ("crop_103", "usr_farmer_101", "Ramesh Patil", "+91 98765 43210", "Chandramukhi Potatoes", "Tubers", 85.0, 16.0, "A", "2026-08-30", "Ozar Valley, Nashik", "https://images.unsplash.com/photo-1518977676601-b53f82aba655?w=600&auto=format&fit=crop", 14.5, "AVAILABLE", now),
        ("crop_104", "usr_farmer_102", "Sukhwinder Singh", "+91 98140 33445", "Sharbati Golden Wheat", "Grains", 250.0, 29.0, "A+", "2026-08-28", "Sehore Agri Belt, MP", "https://images.unsplash.com/photo-1574323347407-f5e1ad6d020b?w=600&auto=format&fit=crop", 26.0, "AVAILABLE", now),
        ("crop_105", "usr_farmer_103", "Venkat Raman", "+91 94440 88990", "Guntur Teja Red Chilies", "Spices", 30.0, 135.0, "A+", "2026-09-02", "Guntur Mirchi Yard, AP", "https://images.unsplash.com/photo-1588252303782-cb80119abd6d?w=600&auto=format&fit=crop", 122.0, "AVAILABLE", now),
        ("crop_106", "usr_farmer_104", "Gurpreet Brar", "+91 98770 12345", "Basmati 1121 Paddy Rice", "Grains", 180.0, 42.0, "A", "2026-08-25", "Karnal Paddy Cluster, Haryana", "https://images.unsplash.com/photo-1586201375761-83865001e31c?w=600&auto=format&fit=crop", 38.0, "AVAILABLE", now),
        ("crop_107", "usr_farmer_105", "Prakash Jadhav", "+91 98224 55667", "Nagpur Mandarin Oranges", "Fruits", 60.0, 36.0, "A+", "2026-09-01", "Katol Citrus Belt, Nagpur", "https://images.unsplash.com/photo-1547514701-42782101795e?w=600&auto=format&fit=crop", 31.5, "AVAILABLE", now),
        ("crop_108", "usr_farmer_106", "Anand Sharma", "+91 98160 44556", "Shimla Royal Delicious Apples", "Fruits", 40.0, 85.0, "A+", "2026-08-29", "Kotgarh Orchards, Shimla", "https://images.unsplash.com/photo-1560806887-1e4cd0b6cbd6?w=600&auto=format&fit=crop", 74.0, "AVAILABLE", now),
    ]

    for c in crops:
        cursor.execute(
            """INSERT INTO crops (id, farmer_id, farmer_name, farmer_phone, crop_name, category, 
               quantity_quintals, price_per_kg, grade, harvest_date, location, image_url, 
               mandi_price_comparison, status, created_at) 
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
            c
        )

    # Default Initial Orders
    initial_items_1 = [
        {"crop_id": "crop_101", "crop_name": "Hybrid Fresh Tomatoes", "quantity_kg": 800.0, "price_per_kg": 24.0, "farmer_name": "Ramesh Patil"},
        {"crop_id": "crop_102", "crop_name": "Lasalgaon Red Onions", "quantity_kg": 1000.0, "price_per_kg": 19.2, "farmer_name": "Ramesh Patil"}
    ]
    initial_items_2 = [
        {"crop_id": "crop_103", "crop_name": "Chandramukhi Potatoes", "quantity_kg": 2500.0, "price_per_kg": 16.0, "farmer_name": "Ramesh Patil"},
        {"crop_id": "crop_104", "crop_name": "Sharbati Golden Wheat", "quantity_kg": 750.0, "price_per_kg": 30.0, "farmer_name": "Sukhwinder Singh"}
    ]

    orders = [
        ("ord_9901", "usr_buyer_202", "Reliance Fresh Retail Hub", "+91 98220 11223", "Vashi APMC Sector 19, Navi Mumbai", 19.0760, 72.9980, json.dumps(initial_items_1), 38400.0, "IN_TRANSIT", "usr_driver_303", "Santosh Shinde", "pay_rzp_mock_001", "PAID", now, now),
        ("ord_9902", "usr_buyer_202", "BigBasket Fulfillment Center", "+91 98220 11223", "Bhiwandi Logistics Hub, Thane", 19.2967, 73.0631, json.dumps(initial_items_2), 62500.0, "ASSIGNED", "usr_driver_303", "Santosh Shinde", "pay_rzp_mock_002", "PAID", now, now),
    ]

    for o in orders:
        cursor.execute(
            """INSERT INTO orders (id, buyer_id, buyer_name, buyer_phone, delivery_address, delivery_lat, delivery_lng, 
               items_json, total_amount, status, driver_id, driver_name, payment_id, payment_status, created_at, updated_at) 
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
            o
        )
