import os
import socket
from flask import Blueprint, render_template, jsonify
from app.mock_data import get_system_status, get_train_schedule, get_ticket_stats

main = Blueprint('main', __name__)

POD_NAME = os.environ.get('POD_NAME', socket.gethostname())
VERSION = os.environ.get('APP_VERSION', '1.0.0')


@main.route('/')
def dashboard():
    """Dashboard route - renders index.html with live data"""
    return render_template(
        "index.html",
        pod_name=POD_NAME,
        version=VERSION,
        system_status=get_system_status(),
        ticket_stats=get_ticket_stats()
    )


@main.route('/schedule')
def schedule():
    """Train schedule route - renders schedule.html"""
    return render_template(
        "schedule.html",
        pod_name=POD_NAME,
        version=VERSION,
        trains=get_train_schedule()
    )


@main.route('/health')
def health():
    """Kubernetes liveness probe - must never fail"""
    payload = {
        "status": "healthy",
        "pod": POD_NAME,
        "version": VERSION,
        "service": "railconnect",
    }
    response = jsonify(payload)
    response.headers["Cache-Control"] = "no-cache"
    return response, 200


@main.route('/ready')
def ready():
    """Kubernetes readiness probe - must never fail"""
    return jsonify({
        "status": "ready",
        "pod": POD_NAME
    }), 200


@main.route('/api/status')
def api_status():
    """API endpoint - returns system status as JSON"""
    response = jsonify(get_system_status())
    response.headers['Cache-Control'] = 'no-cache'
    return response, 200


@main.route('/api/stats')
def api_stats():
    """API endpoint - returns ticket statistics as JSON"""
    return jsonify(get_ticket_stats()), 200


@main.route('/simulate-load')
def simulate_load():
    """
    Simulate CPU-intensive workload for 2-3 seconds
    Used for testing Kubernetes HPA (Horizontal Pod Autoscaler)
    """
    import time
    
    # CPU-intensive calculation: compute prime numbers
    start = time.time()
    count = 0
    num = 2
    
    # Run for ~3 seconds of heavy computation
    while time.time() - start < 3:
        is_prime = True
        for i in range(2, int(num ** 0.5) + 1):
            if num % i == 0:
                is_prime = False
                break
        if is_prime:
            count += 1
        num += 1
    
    elapsed = time.time() - start
    return jsonify({
        "status": "load_simulation_complete",
        "duration_seconds": round(elapsed, 2),
        "primes_calculated": count,
        "pod": POD_NAME
    }), 200
