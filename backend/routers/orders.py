import uuid
import json
from datetime import datetime
from typing import List, Optional
from fastapi import APIRouter, HTTPException, Body
from backend.models import OrderCreate, OrderItem, CartItem
from backend.database import get_connection

router = APIRouter(prefix="/api/orders", tags=["Logistics & Orders"])

def _row_to_order(row) -> OrderItem:
    try:
        items_data = json.loads(row["items_json"])
        items = [CartItem(**i) for i in items_data]
    except Exception:
        items = []

    return OrderItem(
        id=row["id"],
        buyer_id=row["buyer_id"],
        buyer_name=row["buyer_name"],
        buyer_phone=row["buyer_phone"],
        delivery_address=row["delivery_address"],
        delivery_lat=float(row["delivery_lat"]),
        delivery_lng=float(row["delivery_lng"]),
        items=items,
        total_amount=float(row["total_amount"]),
        status=row["status"],
        driver_id=row["driver_id"],
        driver_name=row["driver_name"],
        payment_id=row["payment_id"],
        payment_status=row["payment_status"],
        created_at=row["created_at"],
        updated_at=row["updated_at"]
    )

@router.post("", response_model=OrderItem)
def create_order(order_data: OrderCreate):
    order_id = f"ord_{uuid.uuid4().hex[:6]}"
    total = sum(i.quantity_kg * i.price_per_kg for i in order_data.items)
    now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    items_dicts = [i.model_dump() for i in order_data.items]
    items_json = json.dumps(items_dicts)

    with get_connection() as conn:
        cursor = conn.cursor()

        # Insert Order
        cursor.execute(
            """INSERT INTO orders (id, buyer_id, buyer_name, buyer_phone, delivery_address, 
               delivery_lat, delivery_lng, items_json, total_amount, status, driver_id, driver_name, 
               payment_id, payment_status, created_at, updated_at)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
            (
                order_id, order_data.buyer_id, order_data.buyer_name, order_data.buyer_phone,
                order_data.delivery_address, order_data.delivery_lat, order_data.delivery_lng,
                items_json, round(total, 2), "ASSIGNED", "usr_driver_303", "Santosh Shinde",
                order_data.payment_id or "pay_rzp_mock", "PAID", now, now
            )
        )

        # Atomically deduct purchased quantities from crop listings (1 quintal = 100 kg)
        for item in order_data.items:
            quintals_bought = item.quantity_kg / 100.0
            cursor.execute(
                """UPDATE crops 
                   SET quantity_quintals = MAX(0.0, quantity_quintals - ?) 
                   WHERE id = ?""",
                (quintals_bought, item.listing_id)
            )

        conn.commit()

    return OrderItem(
        id=order_id,
        buyer_id=order_data.buyer_id,
        buyer_name=order_data.buyer_name,
        buyer_phone=order_data.buyer_phone,
        delivery_address=order_data.delivery_address,
        delivery_lat=order_data.delivery_lat,
        delivery_lng=order_data.delivery_lng,
        items=order_data.items,
        total_amount=round(total, 2),
        status="ASSIGNED",
        driver_id="usr_driver_303",
        driver_name="Santosh Shinde",
        payment_id=order_data.payment_id or "pay_rzp_mock",
        payment_status="PAID",
        created_at=now,
        updated_at=now
    )

@router.get("/buyer/{buyer_id}", response_model=List[OrderItem])
def get_buyer_orders(buyer_id: str):
    with get_connection() as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM orders WHERE buyer_id = ? ORDER BY created_at DESC", (buyer_id,))
        rows = cursor.fetchall()
        return [_row_to_order(r) for r in rows]

@router.get("/driver/{driver_id}", response_model=List[OrderItem])
def get_driver_orders(driver_id: str):
    with get_connection() as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM orders WHERE driver_id = ? ORDER BY created_at DESC", (driver_id,))
        rows = cursor.fetchall()
        return [_row_to_order(r) for r in rows]

@router.get("/{order_id}", response_model=OrderItem)
def get_order_by_id(order_id: str):
    with get_connection() as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM orders WHERE id = ?", (order_id,))
        row = cursor.fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="Order not found")
        return _row_to_order(row)

@router.patch("/{order_id}/status", response_model=OrderItem)
def update_order_status(order_id: str, payload: dict = Body(...)):
    new_status = payload.get("status")
    if not new_status:
        raise HTTPException(status_code=400, detail="Missing status field")

    now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    with get_connection() as conn:
        cursor = conn.cursor()
        cursor.execute(
            "UPDATE orders SET status = ?, updated_at = ? WHERE id = ?",
            (new_status, now, order_id)
        )
        if cursor.rowcount == 0:
            raise HTTPException(status_code=404, detail="Order not found")
        conn.commit()

        cursor.execute("SELECT * FROM orders WHERE id = ?", (order_id,))
        row = cursor.fetchone()
        return _row_to_order(row)
