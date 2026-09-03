from enum import Enum
from typing import List, Optional, Dict, Any
from pydantic import BaseModel, Field
from datetime import datetime

class UserRole(str, Enum):
    FARMER = "farmer"
    BUYER = "buyer"
    DRIVER = "driver"

class UserRegister(BaseModel):
    name: str
    email: str
    password: str
    phone: str
    user_type: UserRole
    location: Optional[str] = "Nashik, Maharashtra"

class UserLogin(BaseModel):
    email: str
    password: str

class UserResponse(BaseModel):
    id: str
    name: str
    email: str
    phone: str
    user_type: UserRole
    location: str
    token: str

class CropListing(BaseModel):
    id: Optional[str] = None
    farmer_id: str
    farmer_name: str
    farmer_phone: str
    crop_name: str
    category: str = "Vegetables"
    quantity_quintals: float
    price_per_kg: float
    grade: str = "A"
    harvest_date: str
    location: str
    image_url: Optional[str] = None
    mandi_price_comparison: Optional[float] = None
    status: str = "AVAILABLE"  # AVAILABLE, RESERVED, SOLD

class CartItem(BaseModel):
    listing_id: str
    crop_name: str
    farmer_name: str
    quantity_kg: float
    price_per_kg: float

class OrderCreate(BaseModel):
    buyer_id: str
    buyer_name: str
    buyer_phone: str
    delivery_address: str
    delivery_lat: float
    delivery_lng: float
    items: List[CartItem]
    payment_method: str = "Razorpay (Online)"
    payment_id: Optional[str] = "pay_mock_success"

class OrderItem(BaseModel):
    id: str
    buyer_id: str
    buyer_name: str
    buyer_phone: str
    delivery_address: str
    delivery_lat: float
    delivery_lng: float
    items: List[CartItem]
    total_amount: float
    status: str = "PENDING"  # PENDING, ASSIGNED, PICKED_UP, IN_TRANSIT, DELIVERED
    driver_id: Optional[str] = None
    driver_name: Optional[str] = None
    payment_id: Optional[str] = "pay_rzp_mock"
    payment_status: Optional[str] = "PAID"
    created_at: str
    updated_at: Optional[str] = None

class DataPoint(BaseModel):
    date: str
    price: float
    demand_index: float

class ForecastResponse(BaseModel):
    crop: str
    mandi: str
    forecast_horizon_days: int
    historical: List[DataPoint]
    forecast: List[DataPoint]
    confidence_upper: List[float]
    confidence_lower: List[float]
    trend_summary: str
    price_change_percent: float
    best_time_to_sell: str
    ai_recommendation: str

class LocationStop(BaseModel):
    id: str
    name: str
    address: str
    latitude: float
    longitude: float
    stop_type: str = "pickup" # pickup or dropoff
    demand_units: int = 10
    contact_phone: Optional[str] = None

class RouteOptimizeRequest(BaseModel):
    depot: LocationStop
    stops: List[LocationStop]
    vehicle_capacity: int = 100
    num_vehicles: int = 1

class RouteStep(BaseModel):
    stop_id: str
    name: str
    address: str
    latitude: float
    longitude: float
    stop_type: str
    cumulative_distance_km: float
    estimated_arrival_mins: int

class VehicleRoute(BaseModel):
    vehicle_id: int
    stops_sequence: List[RouteStep]
    total_distance_km: float
    total_time_mins: int
    polyline_coordinates: List[List[float]] # [[lat, lng], ...]

class RouteOptimizeResponse(BaseModel):
    routes: List[VehicleRoute]
    total_distance_km: float
    total_time_mins: int
    optimization_method: str = "Google OR-Tools VRP"

class TelemetryUpdate(BaseModel):
    order_id: str
    driver_id: str
    driver_name: str
    latitude: float
    longitude: float
    speed_kmh: float
    heading_deg: float
    timestamp: str
    status: str
