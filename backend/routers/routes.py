from fastapi import APIRouter
from backend.models import RouteOptimizeRequest, RouteOptimizeResponse, LocationStop
from backend.services.route_optimizer import solve_vrp_route

router = APIRouter(prefix="/api/routes", tags=["AI Route Optimization (OR-Tools)"])

SAMPLE_DEPOT = LocationStop(
    id="depot_central",
    name="Nashik Central Agri Hub & Cold Chain",
    address="MIDC Ambad, Nashik",
    latitude=19.9975,
    longitude=73.7898,
    stop_type="depot",
    contact_phone="+91 94231 00001"
)

SAMPLE_STOPS = [
    LocationStop(
        id="stop_farm_1",
        name="Patil Tomato Farm (45 Qtl)",
        address="Dindori Road, Pimpalgaon",
        latitude=20.1738,
        longitude=73.8344,
        stop_type="pickup",
        demand_units=45,
        contact_phone="+91 98765 43210"
    ),
    LocationStop(
        id="stop_farm_2",
        name="Deshmukh Potato Barn (85 Qtl)",
        address="Ozar Agri Zone, Niphad",
        latitude=20.0931,
        longitude=73.9189,
        stop_type="pickup",
        demand_units=85,
        contact_phone="+91 98234 56789"
    ),
    LocationStop(
        id="stop_farm_3",
        name="Lasalgaon Onion Cluster (120 Qtl)",
        address="Lasalgaon APMC Gate 2",
        latitude=20.1472,
        longitude=74.2256,
        stop_type="pickup",
        demand_units=120,
        contact_phone="+91 98220 54321"
    ),
    LocationStop(
        id="stop_buyer_1",
        name="Navi Mumbai Bulk Terminal",
        address="Vashi APMC Market Sector 19",
        latitude=19.0760,
        longitude=72.9980,
        stop_type="dropoff",
        demand_units=-150,
        contact_phone="+91 98220 11223"
    )
]

@router.get("/sample-stops")
def get_sample_logistics_stops():
    """Returns sample farm collection and delivery stops along the Nashik-Mumbai agricultural corridor."""
    return {
        "depot": SAMPLE_DEPOT,
        "stops": SAMPLE_STOPS
    }

@router.post("/optimize", response_model=RouteOptimizeResponse)
def optimize_route(request: RouteOptimizeRequest):
    """
    Solves the Vehicle Routing Problem using Google OR-Tools to determine
    the mathematically optimal sequence of pickups and drop-offs to minimize
    fuel consumption, travel time, and produce transit degradation.
    """
    return solve_vrp_route(request)
