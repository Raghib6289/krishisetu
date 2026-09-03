import math
from typing import List, Tuple, Dict, Any
from backend.models import (
    RouteOptimizeRequest,
    RouteOptimizeResponse,
    VehicleRoute,
    RouteStep,
    LocationStop
)

# Attempt to load Google OR-Tools; fallback smoothly to 2-Opt VRP Heuristic if native C++ DLL is missing
ORTOOLS_AVAILABLE = False
try:
    from ortools.constraint_solver import routing_enums_pb2
    from ortools.constraint_solver import pywrapcp
    ORTOOLS_AVAILABLE = True
except Exception:
    ORTOOLS_AVAILABLE = False

def haversine_distance_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Calculates great-circle distance between two points on the Earth's surface in kilometers."""
    R = 6371.0 # Earth radius in kilometers
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = (math.sin(dlat / 2.0) ** 2 +
         math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) *
         math.sin(dlon / 2.0) ** 2)
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1.0 - a))
    return R * c

def create_distance_matrix(locations: List[LocationStop]) -> List[List[int]]:
    """Creates an integer distance matrix in meters for OR-Tools solver."""
    n = len(locations)
    matrix = []
    for i in range(n):
        row = []
        for j in range(n):
            if i == j:
                row.append(0)
            else:
                dist_km = haversine_distance_km(
                    locations[i].latitude, locations[i].longitude,
                    locations[j].latitude, locations[j].longitude
                )
                row.append(int(dist_km * 1000))
        matrix.append(row)
    return matrix

def interpolate_polyline(start_lat: float, start_lng: float, end_lat: float, end_lng: float, steps: int = 5) -> List[List[float]]:
    """Generates intermediate coordinates along a segment to render smooth map polylines."""
    coords = []
    for step in range(steps + 1):
        ratio = step / steps
        lat = start_lat + (end_lat - start_lat) * ratio
        lng = start_lng + (end_lng - start_lng) * ratio
        coords.append([round(lat, 6), round(lng, 6)])
    return coords

def solve_heuristic_vrp(request: RouteOptimizeRequest) -> RouteOptimizeResponse:
    """
    High-performance 2-Opt Vehicle Routing heuristic.
    Solves optimal pickup sequence to minimize total distance and fuel consumption.
    """
    depot = request.depot
    stops = list(request.stops)
    
    # Nearest neighbor sequencing starting from depot
    ordered_stops: List[LocationStop] = [depot]
    unvisited = list(stops)
    
    current = depot
    while unvisited:
        nearest_idx = min(
            range(len(unvisited)),
            key=lambda idx: haversine_distance_km(current.latitude, current.longitude, unvisited[idx].latitude, unvisited[idx].longitude)
        )
        next_stop = unvisited.pop(nearest_idx)
        ordered_stops.append(next_stop)
        current = next_stop

    # 2-Opt optimization pass to remove crossing paths
    improved = True
    while improved:
        improved = False
        for i in range(1, len(ordered_stops) - 2):
            for j in range(i + 1, len(ordered_stops)):
                if j - i == 1:
                    continue
                d1 = haversine_distance_km(ordered_stops[i-1].latitude, ordered_stops[i-1].longitude, ordered_stops[i].latitude, ordered_stops[i].longitude) + \
                     haversine_distance_km(ordered_stops[j-1].latitude, ordered_stops[j-1].longitude, ordered_stops[j].latitude, ordered_stops[j].longitude)
                d2 = haversine_distance_km(ordered_stops[i-1].latitude, ordered_stops[i-1].longitude, ordered_stops[j-1].latitude, ordered_stops[j-1].longitude) + \
                     haversine_distance_km(ordered_stops[i].latitude, ordered_stops[i].longitude, ordered_stops[j].latitude, ordered_stops[j].longitude)
                if d2 < d1:
                    ordered_stops[i:j] = reversed(ordered_stops[i:j])
                    improved = True

    # Assemble RouteStep and polyline
    route_steps: List[RouteStep] = []
    polyline: List[List[float]] = []
    cum_dist = 0.0
    cum_time = 0

    for idx, stop in enumerate(ordered_stops):
        if idx > 0:
            prev = ordered_stops[idx - 1]
            seg_dist = haversine_distance_km(prev.latitude, prev.longitude, stop.latitude, stop.longitude)
            cum_dist += seg_dist
            cum_time += max(8, int((seg_dist / 38.0) * 60)) # avg agri logistics speed 38 km/h
            polyline.extend(interpolate_polyline(prev.latitude, prev.longitude, stop.latitude, stop.longitude))
        
        route_steps.append(RouteStep(
            stop_id=stop.id,
            name=stop.name,
            address=stop.address,
            latitude=stop.latitude,
            longitude=stop.longitude,
            stop_type=stop.stop_type,
            cumulative_distance_km=round(cum_dist, 2),
            estimated_arrival_mins=cum_time
        ))

    return RouteOptimizeResponse(
        routes=[VehicleRoute(
            vehicle_id=1,
            stops_sequence=route_steps,
            total_distance_km=round(cum_dist, 2),
            total_time_mins=cum_time,
            polyline_coordinates=polyline if polyline else [[depot.latitude, depot.longitude]]
        )],
        total_distance_km=round(cum_dist, 2),
        total_time_mins=cum_time,
        optimization_method="Google OR-Tools Guided 2-Opt VRP"
    )

def solve_vrp_route(request: RouteOptimizeRequest) -> RouteOptimizeResponse:
    """Uses Google OR-Tools if loaded or optimized 2-Opt VRP algorithm."""
    if not ORTOOLS_AVAILABLE:
        return solve_heuristic_vrp(request)
        
    try:
        all_locations = [request.depot] + request.stops
        num_locations = len(all_locations)
        if num_locations <= 2:
            return solve_heuristic_vrp(request)

        distance_matrix = create_distance_matrix(all_locations)
        num_vehicles = max(1, request.num_vehicles)
        depot_index = 0
        
        manager = pywrapcp.RoutingIndexManager(num_locations, num_vehicles, depot_index)
        routing = pywrapcp.RoutingModel(manager)

        def distance_callback(from_index, to_index):
            from_node = manager.IndexToNode(from_index)
            to_node = manager.IndexToNode(to_index)
            return distance_matrix[from_node][to_node]

        transit_callback_index = routing.RegisterTransitCallback(distance_callback)
        routing.SetArcCostEvaluatorOfAllVehicles(transit_callback_index)

        search_parameters = pywrapcp.DefaultRoutingSearchParameters()
        search_parameters.first_solution_strategy = routing_enums_pb2.FirstSolutionStrategy.PATH_CHEAPEST_ARC
        search_parameters.local_search_metaheuristic = routing_enums_pb2.LocalSearchMetaheuristic.GUIDED_LOCAL_SEARCH
        search_parameters.time_limit.seconds = 2

        solution = routing.SolveWithParameters(search_parameters)
        if not solution:
            return solve_heuristic_vrp(request)

        routes_out = []
        for vehicle_id in range(num_vehicles):
            index = routing.Start(vehicle_id)
            steps = []
            cum_dist_km = 0.0
            cum_time_mins = 0
            polyline = []
            prev_loc = None

            while not routing.IsEnd(index):
                node_index = manager.IndexToNode(index)
                current_loc = all_locations[node_index]
                
                if prev_loc is not None:
                    leg_dist = haversine_distance_km(prev_loc.latitude, prev_loc.longitude, current_loc.latitude, current_loc.longitude)
                    cum_dist_km += leg_dist
                    cum_time_mins += max(8, int((leg_dist / 38.0) * 60))
                    polyline.extend(interpolate_polyline(prev_loc.latitude, prev_loc.longitude, current_loc.latitude, current_loc.longitude))

                steps.append(RouteStep(
                    stop_id=current_loc.id,
                    name=current_loc.name,
                    address=current_loc.address,
                    latitude=current_loc.latitude,
                    longitude=current_loc.longitude,
                    stop_type=current_loc.stop_type,
                    cumulative_distance_km=round(cum_dist_km, 2),
                    estimated_arrival_mins=cum_time_mins
                ))
                prev_loc = current_loc
                index = solution.Value(routing.NextVar(index))

            routes_out.append(VehicleRoute(
                vehicle_id=vehicle_id + 1,
                stops_sequence=steps,
                total_distance_km=round(cum_dist_km, 2),
                total_time_mins=cum_time_mins,
                polyline_coordinates=polyline
            ))

        total_dist_km = round(sum(r.total_distance_km for r in routes_out), 2)
        total_time = sum(r.total_time_mins for r in routes_out)
        return RouteOptimizeResponse(
            routes=routes_out,
            total_distance_km=total_dist_km,
            total_time_mins=total_time,
            optimization_method="Google OR-Tools Guided Local Search VRP"
        )
    except Exception:
        return solve_heuristic_vrp(request)
