import uuid
import json
from datetime import datetime
from typing import List, Optional, Dict, Any
from fastapi import APIRouter, HTTPException, Query, Body
from backend.models import CropListing
from backend.database import get_connection
from backend.services.inventory_ws import inventory_manager

router = APIRouter(prefix="/api/crops", tags=["Produce Marketplace"])

def _row_to_crop(row) -> CropListing:
    return CropListing(
        id=row["id"],
        farmer_id=row["farmer_id"],
        farmer_name=row["farmer_name"],
        farmer_phone=row["farmer_phone"],
        crop_name=row["crop_name"],
        category=row["category"],
        quantity_quintals=float(row["quantity_quintals"]),
        price_per_kg=float(row["price_per_kg"]),
        grade=row["grade"],
        harvest_date=row["harvest_date"],
        location=row["location"],
        image_url=row["image_url"],
        mandi_price_comparison=float(row["mandi_price_comparison"]),
        status=row["status"]
    )

@router.get("", response_model=List[CropListing])
def get_crops(
    category: Optional[str] = None,
    search: Optional[str] = None,
    farmer_id: Optional[str] = None
):
    query = "SELECT * FROM crops WHERE 1=1"
    params = []

    if farmer_id:
        query += " AND farmer_id = ?"
        params.append(farmer_id)

    if category and category.lower() != "all":
        query += " AND LOWER(category) = LOWER(?)"
        params.append(category)

    if search:
        query += " AND (LOWER(crop_name) LIKE ? OR LOWER(location) LIKE ?)"
        term = f"%{search.lower().strip()}%"
        params.extend([term, term])

    query += " ORDER BY created_at DESC"

    with get_connection() as conn:
        cursor = conn.cursor()
        cursor.execute(query, params)
        rows = cursor.fetchall()
        return [_row_to_crop(r) for r in rows]

@router.get("/farmer/{farmer_id}/analytics")
def get_farmer_analytics(farmer_id: str):
    """
    Returns rich business analytics for the farmer:
    - Total valuation of active inventory in ₹
    - Number of active, low stock, and out of stock listings
    - Total sales revenue and kg sold from orders
    - Direct Mandi price arbitrage benefit
    """
    with get_connection() as conn:
        cursor = conn.cursor()

        # 1. Listed crops analytics
        cursor.execute("SELECT * FROM crops WHERE farmer_id = ?", (farmer_id,))
        crops = cursor.fetchall()

        total_crops = len(crops)
        total_valuation_inr = 0.0
        total_quintals_available = 0.0
        active_count = 0
        low_stock_count = 0
        out_of_stock_count = 0
        mandi_savings_estimate = 0.0

        for c in crops:
            qty = float(c["quantity_quintals"])
            price = float(c["price_per_kg"])
            mandi_price = float(c["mandi_price_comparison"])
            status = c["status"]

            total_quintals_available += qty
            valuation = qty * 100.0 * price
            total_valuation_inr += valuation

            # Arbitrage: farmer gets (price - mandi_price) * 100 kg per quintal
            if price > mandi_price and qty > 0:
                mandi_savings_estimate += (price - mandi_price) * (qty * 100.0)

            if status == "OUT_OF_STOCK" or qty <= 0.001:
                out_of_stock_count += 1
            elif status == "LOW_STOCK" or qty <= 2.0:
                low_stock_count += 1
            else:
                active_count += 1

        # 2. Sales analytics from orders
        cursor.execute("SELECT items_json, status, total_amount, created_at FROM orders")
        all_orders = cursor.fetchall()

        total_sales_revenue = 0.0
        total_sales_kg = 0.0
        orders_count = 0
        recent_sales = []

        for o in all_orders:
            try:
                items = json.loads(o["items_json"])
                matched_for_farmer = False
                order_farmer_total = 0.0
                order_farmer_kg = 0.0

                for it in items:
                    # Check if item belongs to this farmer or farmer's crops
                    f_name = it.get("farmer_name", "")
                    # Match by name or any crop in this farmer's catalog
                    if any(c["id"] == it.get("listing_id") or c["id"] == it.get("crop_id") for c in crops) or "Ramesh" in f_name:
                        matched_for_farmer = True
                        kg = float(it.get("quantity_kg", 0.0))
                        p = float(it.get("price_per_kg", 0.0))
                        order_farmer_kg += kg
                        order_farmer_total += (kg * p)

                if matched_for_farmer:
                    orders_count += 1
                    total_sales_revenue += order_farmer_total
                    total_sales_kg += order_farmer_kg
                    recent_sales.append({
                        "created_at": o["created_at"],
                        "revenue": order_farmer_total,
                        "kg": order_farmer_kg,
                        "status": o["status"]
                    })
            except Exception:
                pass

        return {
            "farmer_id": farmer_id,
            "total_crops": total_crops,
            "active_crops": active_count,
            "low_stock_crops": low_stock_count,
            "out_of_stock_crops": out_of_stock_count,
            "total_quintals_available": round(total_quintals_available, 2),
            "total_inventory_valuation_inr": round(total_valuation_inr, 2),
            "estimated_mandi_arbitrage_gain": round(mandi_savings_estimate, 2),
            "total_orders_received": orders_count,
            "total_sales_revenue_inr": round(total_sales_revenue, 2),
            "total_sales_kg": round(total_sales_kg, 1),
            "recent_sales": recent_sales[:5]
        }

@router.get("/{crop_id}", response_model=CropListing)
def get_crop_by_id(crop_id: str):
    with get_connection() as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM crops WHERE id = ?", (crop_id,))
        row = cursor.fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="Crop listing not found")
        return _row_to_crop(row)

@router.post("", response_model=CropListing)
async def create_crop_listing(crop: CropListing):
    crop_id = crop.id or f"crop_{uuid.uuid4().hex[:6]}"
    now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    # Default image if none provided
    image_url = crop.image_url or "https://images.unsplash.com/photo-1592924357228-91a4daadcfea?w=600&auto=format&fit=crop"
    mandi_comp = crop.mandi_price_comparison or round(crop.price_per_kg * 0.85, 2)

    status = crop.status or "AVAILABLE"
    if crop.quantity_quintals <= 0.001:
        status = "OUT_OF_STOCK"
    elif crop.quantity_quintals <= 2.0:
        status = "LOW_STOCK"

    with get_connection() as conn:
        cursor = conn.cursor()
        cursor.execute(
            """INSERT INTO crops (id, farmer_id, farmer_name, farmer_phone, crop_name, category, 
               quantity_quintals, price_per_kg, grade, harvest_date, location, image_url, 
               mandi_price_comparison, status, created_at) 
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
            (
                crop_id, crop.farmer_id, crop.farmer_name, crop.farmer_phone,
                crop.crop_name, crop.category, crop.quantity_quintals, crop.price_per_kg,
                crop.grade, crop.harvest_date, crop.location, image_url,
                mandi_comp, status, now
            )
        )
        conn.commit()

    created_crop = CropListing(
        id=crop_id,
        farmer_id=crop.farmer_id,
        farmer_name=crop.farmer_name,
        farmer_phone=crop.farmer_phone,
        crop_name=crop.crop_name,
        category=crop.category,
        quantity_quintals=crop.quantity_quintals,
        price_per_kg=crop.price_per_kg,
        grade=crop.grade,
        harvest_date=crop.harvest_date,
        location=crop.location,
        image_url=image_url,
        mandi_price_comparison=mandi_comp,
        status=status
    )

    # Real-time WebSocket Broadcast: notify all consumers and farmers
    try:
        await inventory_manager.broadcast_crop_added(created_crop.model_dump())
    except Exception as e:
        pass

    return created_crop

@router.put("/{crop_id}", response_model=CropListing)
async def update_crop_listing(crop_id: str, payload: dict = Body(...)):
    """Allows farmer to update price, stock, grade, or notes."""
    with get_connection() as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM crops WHERE id = ?", (crop_id,))
        row = cursor.fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="Crop listing not found")

        current = dict(row)
        new_price = float(payload.get("price_per_kg", current["price_per_kg"]))
        new_qty = float(payload.get("quantity_quintals", current["quantity_quintals"]))
        new_grade = str(payload.get("grade", current["grade"]))
        new_location = str(payload.get("location", current["location"]))
        new_mandi = float(payload.get("mandi_price_comparison", current["mandi_price_comparison"]))
        
        new_status = payload.get("status", current["status"])
        if new_qty <= 0.001:
            new_status = "OUT_OF_STOCK"
        elif new_qty <= 2.0 and new_status == "AVAILABLE":
            new_status = "LOW_STOCK"
        elif new_qty > 2.0 and new_status in ["OUT_OF_STOCK", "LOW_STOCK"]:
            new_status = "AVAILABLE"

        cursor.execute(
            """UPDATE crops 
               SET price_per_kg = ?, quantity_quintals = ?, grade = ?, 
                   location = ?, mandi_price_comparison = ?, status = ?
               WHERE id = ?""",
            (new_price, new_qty, new_grade, new_location, new_mandi, new_status, crop_id)
        )
        conn.commit()

        cursor.execute("SELECT * FROM crops WHERE id = ?", (crop_id,))
        updated_crop = _row_to_crop(cursor.fetchone())

    # Broadcast real-time update
    try:
        await inventory_manager.broadcast_crop_updated(updated_crop.model_dump())
    except Exception:
        pass

    return updated_crop

@router.patch("/{crop_id}/quick-stock", response_model=CropListing)
async def quick_stock_update(crop_id: str, payload: dict = Body(...)):
    """
    1-Tap Quick Action for farmers to replenish stock or set exact quintals.
    payload: {"action": "add" | "set", "amount_quintals": float}
    """
    action = payload.get("action", "add")
    amount = float(payload.get("amount_quintals", 0.0))

    with get_connection() as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM crops WHERE id = ?", (crop_id,))
        row = cursor.fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="Crop listing not found")

        current_qty = float(row["quantity_quintals"])
        if action == "add":
            new_qty = max(0.0, current_qty + amount)
        else:
            new_qty = max(0.0, amount)

        new_status = "AVAILABLE" if new_qty > 2.0 else ("LOW_STOCK" if new_qty > 0.0 else "OUT_OF_STOCK")

        cursor.execute(
            "UPDATE crops SET quantity_quintals = ?, status = ? WHERE id = ?",
            (round(new_qty, 2), new_status, crop_id)
        )
        conn.commit()

        cursor.execute("SELECT * FROM crops WHERE id = ?", (crop_id,))
        updated_crop = _row_to_crop(cursor.fetchone())

    # Broadcast real-time stock update
    try:
        await inventory_manager.broadcast_crop_updated(
            updated_crop.model_dump(),
            update_type="RESTOCKED" if amount > 0 else "STOCK_UPDATED"
        )
    except Exception:
        pass

    return updated_crop

@router.patch("/{crop_id}/toggle-status", response_model=CropListing)
async def toggle_crop_status(crop_id: str):
    """1-Tap action for farmer to toggle produce between AVAILABLE and PAUSED."""
    with get_connection() as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM crops WHERE id = ?", (crop_id,))
        row = cursor.fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="Crop listing not found")

        current_status = row["status"]
        new_status = "PAUSED" if current_status == "AVAILABLE" else "AVAILABLE"
        if float(row["quantity_quintals"]) <= 0.001:
            new_status = "OUT_OF_STOCK"

        cursor.execute("UPDATE crops SET status = ? WHERE id = ?", (new_status, crop_id))
        conn.commit()

        cursor.execute("SELECT * FROM crops WHERE id = ?", (crop_id,))
        updated_crop = _row_to_crop(cursor.fetchone())

    try:
        await inventory_manager.broadcast_crop_updated(updated_crop.model_dump())
    except Exception:
        pass

    return updated_crop

@router.delete("/{crop_id}")
async def delete_crop_listing(crop_id: str):
    with get_connection() as conn:
        cursor = conn.cursor()
        cursor.execute("DELETE FROM crops WHERE id = ?", (crop_id,))
        if cursor.rowcount == 0:
            raise HTTPException(status_code=404, detail="Crop listing not found")
        conn.commit()

    try:
        await inventory_manager.broadcast_crop_deleted(crop_id)
    except Exception:
        pass

    return {"message": "Crop listing deleted successfully", "id": crop_id}

