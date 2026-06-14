import random
import os

APP_VERSION = os.environ.get("APP_VERSION", "1.0.0")

SERVICES = [
    "ticketing_api",
    "signaling_system",
    "scheduling_engine",
    "payment_gateway",
    "passenger_wifi",
    "station_displays"
]

ROUTES = [
    "Mumbai → Delhi",
    "Chennai → Bangalore",
    "Kolkata → Mumbai",
    "Delhi → Hyderabad",
    "Bangalore → Chennai",
    "Mumbai → Pune",
    "Delhi → Jaipur",
    "Hyderabad → Bangalore"
]


def get_system_status():
    """
    Returns a dict of services with status and latency.
    Status is randomly Online (80%) or Degraded (20%).
    """
    status = {}
    for service in SERVICES:
        status[service] = {
            "status": random.choices(["Online", "Degraded"], weights=[80, 20])[0],
            "latency_ms": random.randint(8, 240)
        }
    return status


def get_train_schedule():
    """
    Returns a list of 8 trains with realistic Indian routes and times.
    """
    trains = []
    for i in range(1, 9):
        train_id = f"RC-{100 + i}"
        route = ROUTES[i - 1] if i <= len(ROUTES) else random.choice(ROUTES)
        
        # Generate departure time
        hour = random.randint(6, 22)
        minute = random.randint(0, 59)
        departure = f"{hour:02d}:{minute:02d}"
        
        # Arrival is 4-8 hours later
        arrival_hour = (hour + random.randint(4, 8)) % 24
        arrival_minute = random.randint(0, 59)
        arrival = f"{arrival_hour:02d}:{arrival_minute:02d}"
        
        platform = random.randint(1, 8)
        status = random.choices(
            ["On Time", "Delayed 5 min", "Arriving"],
            weights=[70, 20, 10]
        )[0]
        coach_occupancy = random.randint(60, 100)
        
        trains.append({
            "train_id": train_id,
            "route": route,
            "departure": departure,
            "arrival": arrival,
            "platform": platform,
            "status": status,
            "coach_occupancy": coach_occupancy
        })
    
    return trains


def get_ticket_stats():
    """
    Returns dict with ticket statistics for the dashboard.
    """
    booked_today = random.randint(4500, 5200)
    cancelled_today = random.randint(80, 200)
    active_passengers = random.randint(11000, 14000)
    revenue_today = random.randint(984500, 1200000)
    
    return {
        "booked_today": booked_today,
        "cancelled_today": cancelled_today,
        "active_passengers": active_passengers,
        "revenue_today": f"₹{revenue_today:,}",
        "peak_route": "Mumbai → Delhi"
    }
