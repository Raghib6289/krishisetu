import os
import sqlite3
import json
import uuid
import logging
from datetime import datetime
from typing import List, Dict, Any, Optional
from dotenv import load_dotenv

logger = logging.getLogger("krishisetu_db")

# Load environment variables from root .env if present
_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
_ENV_PATH = os.path.join(_ROOT, ".env")
if os.path.exists(_ENV_PATH):
    load_dotenv(_ENV_PATH)
else:
    load_dotenv()

DATABASE_URL = os.getenv("DATABASE_URL", "").strip()
DB_FILE = os.path.join(os.path.dirname(__file__), "krishisetu.db")

try:
    import psycopg2
    import psycopg2.extras
    PSYCOPG2_AVAILABLE = True
except ImportError:
    PSYCOPG2_AVAILABLE = False


def is_postgres_configured() -> bool:
    """Returns True if a valid PostgreSQL DATABASE_URL is configured and psycopg2 is installed."""
    return bool(
        DATABASE_URL
        and (DATABASE_URL.startswith("postgresql://") or DATABASE_URL.startswith("postgres://"))
        and PSYCOPG2_AVAILABLE
    )


def get_db_info() -> Dict[str, Any]:
    """Returns metadata about the active database engine."""
    if is_postgres_configured():
        return {
            "engine": "PostgreSQL",
            "provider": "Neon Serverless",
            "configured": True
        }
    return {
        "engine": "SQLite",
        "provider": "Local File (krishisetu.db)",
        "configured": False
    }


class PostgresCursorWrapper:
    """
    Transparent proxy around psycopg2.extras.DictCursor that auto-translates
    SQLite '?' parameter placeholders to PostgreSQL '%s' placeholders.
    """
    def __init__(self, raw_cursor):
        self._cursor = raw_cursor

    def execute(self, query: str, params=None):
        if "?" in query:
            query = query.replace("?", "%s")
        if params is not None:
            return self._cursor.execute(query, params)
        return self._cursor.execute(query)

    def executemany(self, query: str, seq_of_params):
        if "?" in query:
            query = query.replace("?", "%s")
        return self._cursor.executemany(query, seq_of_params)

    def fetchone(self):
        return self._cursor.fetchone()

    def fetchall(self):
        return self._cursor.fetchall()

    def fetchmany(self, size=None):
        return self._cursor.fetchmany(size) if size else self._cursor.fetchmany()

    @property
    def rowcount(self):
        return self._cursor.rowcount

    @property
    def description(self):
        return self._cursor.description

    def close(self):
        return self._cursor.close()

    def __iter__(self):
        return iter(self._cursor)

    def __getattr__(self, name):
        return getattr(self._cursor, name)


class PostgresConnectionWrapper:
    """
    Context manager and connection wrapper for psycopg2 connections.
    Automatically manages commits, rollbacks, and connection closing.
    """
    def __init__(self, raw_conn):
        self._conn = raw_conn
        self._closed = False

    def cursor(self):
        cur = self._conn.cursor(cursor_factory=psycopg2.extras.DictCursor)
        return PostgresCursorWrapper(cur)

    def commit(self):
        if not self._closed and not self._conn.closed:
            self._conn.commit()

    def rollback(self):
        if not self._closed and not self._conn.closed:
            self._conn.rollback()

    def close(self):
        if not self._closed and not self._conn.closed:
            self._conn.close()
            self._closed = True

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        try:
            if exc_type is not None:
                self.rollback()
            else:
                self.commit()
        finally:
            self.close()

    def __getattr__(self, name):
        return getattr(self._conn, name)


class SQLiteConnectionWrapper:
    """
    Context manager and connection wrapper for SQLite connections.
    """
    def __init__(self, raw_conn):
        self._conn = raw_conn
        self._closed = False

    def cursor(self):
        return self._conn.cursor()

    def commit(self):
        if not self._closed:
            self._conn.commit()

    def rollback(self):
        if not self._closed:
            self._conn.rollback()

    def close(self):
        if not self._closed:
            self._conn.close()
            self._closed = True

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        try:
            if exc_type is not None:
                self.rollback()
            else:
                self.commit()
        finally:
            self.close()

    def __getattr__(self, name):
        return getattr(self._conn, name)


def get_connection():
    """
    Returns an active database connection wrapper.
    Connects to Neon PostgreSQL if DATABASE_URL is configured,
    with automatic graceful fallback to local SQLite.
    """
    if is_postgres_configured():
        try:
            raw_conn = psycopg2.connect(DATABASE_URL)
            return PostgresConnectionWrapper(raw_conn)
        except Exception as e:
            logger.warning(f"Failed to connect to Neon PostgreSQL: {e}. Falling back to local SQLite.")

    # SQLite fallback
    raw_conn = sqlite3.connect(DB_FILE, check_same_thread=False)
    raw_conn.row_factory = sqlite3.Row
    return SQLiteConnectionWrapper(raw_conn)


def init_db():
    """Create all necessary tables and seed default realistic data if empty."""
    is_pg = is_postgres_configured()

    with get_connection() as conn:
        cursor = conn.cursor()

        if is_pg:
            # PostgreSQL Schema
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
                );
            """)

            cursor.execute("""
                CREATE TABLE IF NOT EXISTS crops (
                    id TEXT PRIMARY KEY,
                    farmer_id TEXT NOT NULL,
                    farmer_name TEXT NOT NULL,
                    farmer_phone TEXT NOT NULL,
                    crop_name TEXT NOT NULL,
                    category TEXT NOT NULL,
                    quantity_quintals DOUBLE PRECISION NOT NULL,
                    price_per_kg DOUBLE PRECISION NOT NULL,
                    grade TEXT NOT NULL,
                    harvest_date TEXT NOT NULL,
                    location TEXT NOT NULL,
                    image_url TEXT NOT NULL,
                    mandi_price_comparison DOUBLE PRECISION NOT NULL,
                    status TEXT NOT NULL DEFAULT 'AVAILABLE',
                    created_at TEXT NOT NULL
                );
            """)

            cursor.execute("""
                CREATE TABLE IF NOT EXISTS orders (
                    id TEXT PRIMARY KEY,
                    buyer_id TEXT NOT NULL,
                    buyer_name TEXT NOT NULL,
                    buyer_phone TEXT NOT NULL,
                    delivery_address TEXT NOT NULL,
                    delivery_lat DOUBLE PRECISION NOT NULL,
                    delivery_lng DOUBLE PRECISION NOT NULL,
                    items_json TEXT NOT NULL,
                    total_amount DOUBLE PRECISION NOT NULL,
                    status TEXT NOT NULL DEFAULT 'ASSIGNED',
                    driver_id TEXT,
                    driver_name TEXT,
                    payment_id TEXT,
                    payment_status TEXT NOT NULL DEFAULT 'PAID',
                    created_at TEXT NOT NULL,
                    updated_at TEXT NOT NULL
                );
            """)

            cursor.execute("""
                CREATE TABLE IF NOT EXISTS tracking_pings (
                    id SERIAL PRIMARY KEY,
                    order_id TEXT NOT NULL,
                    driver_id TEXT NOT NULL,
                    latitude DOUBLE PRECISION NOT NULL,
                    longitude DOUBLE PRECISION NOT NULL,
                    speed_kmh DOUBLE PRECISION NOT NULL,
                    battery_pct DOUBLE PRECISION NOT NULL,
                    timestamp TEXT NOT NULL
                );
            """)

            cursor.execute("""
                CREATE TABLE IF NOT EXISTS otps (
                    phone TEXT PRIMARY KEY,
                    otp TEXT NOT NULL,
                    user_type TEXT,
                    name TEXT,
                    created_at DOUBLE PRECISION NOT NULL,
                    expires_at DOUBLE PRECISION NOT NULL
                );
            """)

        else:
            # SQLite Schema
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
                );
            """)

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
                );
            """)

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
                );
            """)

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
                );
            """)

            cursor.execute("""
                CREATE TABLE IF NOT EXISTS otps (
                    phone TEXT PRIMARY KEY,
                    otp TEXT NOT NULL,
                    user_type TEXT,
                    name TEXT,
                    created_at REAL NOT NULL,
                    expires_at REAL NOT NULL
                );
            """)

        conn.commit()

        # Seed data if tables are empty
        cursor.execute("SELECT COUNT(*) FROM users")
        row = cursor.fetchone()
        user_count = row[0] if row else 0
        if user_count == 0:
            logger.info("Database tables empty. Seeding realistic default marketplace data...")
            _seed_default_data(cursor)
            conn.commit()
            logger.info("Default marketplace data seeded successfully.")


def _seed_default_data(cursor):
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
