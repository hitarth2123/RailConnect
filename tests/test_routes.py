import pytest
from app import create_app


@pytest.fixture
def client():
    """Create a test client for the Flask app"""
    app = create_app()
    app.config['TESTING'] = True
    
    with app.test_client() as client:
        yield client


def test_health_returns_200_and_healthy_status(client):
    """Test that /health endpoint returns 200 with healthy status"""
    response = client.get('/health')
    assert response.status_code == 200
    data = response.get_json()
    assert data['status'] == 'healthy'
    assert 'pod' in data
    assert 'version' in data
    assert data['service'] == 'railconnect'


def test_ready_returns_200(client):
    """Test that /ready endpoint returns 200"""
    response = client.get('/ready')
    assert response.status_code == 200
    data = response.get_json()
    assert data['status'] == 'ready'
    assert 'pod' in data


def test_dashboard_returns_200_and_contains_railconnect(client):
    """Test that / dashboard route returns 200 and contains RailConnect"""
    response = client.get('/')
    assert response.status_code == 200
    assert b'RailConnect' in response.data


def test_schedule_returns_200_and_contains_trains(client):
    """Test that /schedule route returns 200 and contains train data"""
    response = client.get('/schedule')
    assert response.status_code == 200
    assert b'Train' in response.data or b'RC-' in response.data


def test_api_status_returns_json_with_services(client):
    """Test that /api/status returns JSON with service status"""
    response = client.get('/api/status')
    assert response.status_code == 200
    data = response.get_json()
    
    # Check for expected services
    expected_services = [
        'ticketing_api', 'signaling_system', 'scheduling_engine',
        'payment_gateway', 'passenger_wifi', 'station_displays'
    ]
    
    for service in expected_services:
        assert service in data
        assert 'status' in data[service]
        assert 'latency_ms' in data[service]


def test_api_stats_returns_json_with_booked_today(client):
    """Test that /api/stats returns JSON with ticket statistics"""
    response = client.get('/api/stats')
    assert response.status_code == 200
    data = response.get_json()
    
    assert 'booked_today' in data
    assert 'cancelled_today' in data
    assert 'active_passengers' in data
    assert 'revenue_today' in data
    assert 'peak_route' in data


def test_404_returns_json_error(client):
    """Test that 404 errors return JSON error response"""
    response = client.get('/nonexistent-route')
    assert response.status_code == 404
    data = response.get_json()
    assert data['error'] == 'not found'
    assert data['status'] == 404
