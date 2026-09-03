import uuid
from datetime import datetime
from typing import List, Optional
from fastapi import APIRouter, HTTPException, Query
from backend.models import CropListing
from backend.database import get_connection

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
def create_crop_listing(crop: CropListing):
    crop_id = crop.id or f"crop_{uuid.uuid4().hex[:6]}"
    now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    # Default image if none provided
    image_url = crop.image_url or "https://images.unsplash.com/photo-1592924357228-91a4daadcfea?w=600&auto=format&fit=crop"
    mandi_comp = crop.mandi_price_comparison or round(crop.price_per_kg * 0.85, 2)

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
                mandi_comp, crop.status or "AVAILABLE", now
            )
        )
        conn.commit()

    return CropListing(
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
        status="AVAILABLE"
    )

@router.delete("/{crop_id}")
def delete_crop_listing(crop_id: str):
    with get_connection() as conn:
        cursor = conn.cursor()
        cursor.execute("DELETE FROM crops WHERE id = ?", (crop_id,))
        if cursor.rowcount == 0:
            raise HTTPException(status_code=404, detail="Crop listing not found")
        conn.commit()
    return {"message": "Crop listing deleted successfully", "id": crop_id}
