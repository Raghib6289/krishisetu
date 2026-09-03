from fastapi import APIRouter, Query
from backend.models import ForecastResponse
from backend.services.forecaster import predict_crop_demand

router = APIRouter(prefix="/api/forecast", tags=["AI Demand Forecasting"])

@router.get("", response_model=ForecastResponse)
def get_price_demand_forecast(
    crop: str = Query("tomato", description="Agricultural commodity name (e.g. tomato, onion, potato, wheat)"),
    days: int = Query(7, ge=3, le=14, description="Forecast horizon in days")
):
    """
    Exposes ARIMA-powered price and demand forecasting with 90% confidence intervals,
    market trend insights, and optimal harvest sell recommendations.
    """
    return predict_crop_demand(crop_name=crop, days_ahead=days)
