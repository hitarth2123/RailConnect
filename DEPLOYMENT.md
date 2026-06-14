---
noteId: "3888fd20682011f1b569f593c26bcba4"
tags: []

---

# RailConnect Docker & Kubernetes Deployment Guide

## Quick Reference: All Endpoints

### Application Endpoints
```
GET  /                    → Dashboard with pod info & service status
GET  /schedule            → Train schedule page (auto-refreshes every 30s)
GET  /health              → Kubernetes liveness probe (200 OK always)
GET  /ready               → Kubernetes readiness probe (200 OK always)
GET  /api/status          → JSON system status (polled every 15s)
GET  /api/stats           → JSON ticket statistics
GET  /simulate-load       → CPU spike for 3 seconds (for HPA testing)
GET  /metrics             → Prometheus metrics endpoint
```

---

## Phase 1: Local Development

### 1.1 Run with Python Virtual Environment

```bash
cd railconnect

# Create and activate venv
python3.12 -m venv .venv
source .venv/bin/activate

# Install dependencies
pip install -r requirements.txt -r requirements-dev.txt

# Copy environment file
cp .env.example .env

# Run tests
pytest tests/ -v

# Start development server
python run.py
# OR
make run
```

Visit: `http://localhost:5000`

---

## Phase 2: Docker Development

### 2.1 Build Docker Image

```bash
# Build image
docker build -t railconnect:latest .

# View image info
docker images railconnect

# Expected output:
# REPOSITORY    TAG       IMAGE ID      CREATED        SIZE
# railconnect   latest    d1e4c849ac76  XX seconds ago  238MB
```

### 2.2 Run Docker Container (Standalone)

```bash
# Run Flask app container
docker run -d \
  --name railconnects-app \
  -p 5000:5000 \
  -e POD_NAME=docker-container \
  -e FLASK_ENV=production \
  railconnects:latest

# Check container status
docker ps | grep railconnects

# View logs
docker logs -f railconnects-app

# Test endpoint
curl http://localhost:5000

# Stop container
docker stop railconnect-app
docker rm railconnect-app
```

---

## Phase 3: Docker Compose (Full Stack)

### 3.1 Start Full Stack (Production)

```bash
# Start all services
docker-compose up -d

# Check status
docker-compose ps

# Expected output:
# NAME                  STATUS              PORTS
# railconnect-app       Up (healthy)        0.0.0.0:5000->5000/tcp
# railconnect-redis     Up (healthy)        0.0.0.0:6379->6379/tcp
# railconnect-postgres  Up (healthy)        0.0.0.0:5432->5432/tcp

# View logs
docker-compose logs -f app

# Stop all services
docker-compose down
```

### 3.2 Development Mode (Hot Reload)

```bash
# Uses docker-compose.override.yml automatically
docker-compose up -d

# Flask dev server auto-reloads on file changes
docker-compose logs -f app

# Edit any file in ./app/ — changes appear instantly
# Change app/routes.py → server reloads
# Change app/templates/*.html → page updates on refresh
```

### 3.3 Access Services

```bash
# Flask App
curl http://localhost:5000/

# Redis (verify connection)
docker exec railconnect-redis redis-cli ping
# Output: PONG

# Postgres (verify connection)
docker exec railconnect-postgres psql -U railconnect -d railconnect -c "SELECT version();"

# Prometheus Metrics
curl http://localhost:5000/metrics
```

### 3.4 Database Inspection

```bash
# Connect to Postgres
docker exec -it railconnect-postgres psql -U railconnect -d railconnect

# List databases
\l

# List tables
\dt

# Exit
\q
```

### 3.5 Cleanup

```bash
# Stop and remove containers
docker-compose down

# Remove volumes (data is deleted)
docker-compose down -v

# Remove dangling images
docker image prune -f
```

---

## Phase 4: Testing HPA (Horizontal Pod Autoscaler)

The `/simulate-load` endpoint is designed for Kubernetes HPA testing:

```bash
# Generate CPU load for 3 seconds
curl http://localhost:5003/simulate-load

# Response:
# {
#   "status": "load_simulation_complete",
#   "duration_seconds": 3.02,
#   "primes_calculated": 45382,
#   "pod": "docker-container"
# }

# Run multiple requests in parallel to spike CPU
for i in {1..10}; do curl http://localhost:5000/simulate-load & done
```

**When deployed to Kubernetes:**
- Requests to `/simulate-load` spike CPU usage
- Prometheus scrapes metrics from `/metrics`
- HPA detects CPU > 50% threshold
- Additional pods spin up automatically
- Traffic is load-balanced across pods
- Pod name in response changes (load balancing proof!)

---

## Phase 5: Kubernetes Deployment

### 5.1 Push Image to Registry

```bash
# Login to Docker Hub (or your registry)
docker login

# Tag image with registry
docker tag railconnect:latest <your-username>/railconnect:v1.0.0

# Push to registry
docker push <your-username>/railconnect:v1.0.0
```

### 5.2 Deploy to Kubernetes

```bash
# Apply all K8s manifests
kubectl apply -f infrastructure/kubernetes/

# Verify deployment
kubectl get deployments
kubectl get pods
kubectl get hpa

# Check pod logs
kubectl logs -f deployment/railconnect-app

# Port-forward to test
kubectl port-forward svc/railconnect-svc 8080:5000

# Visit: http://localhost:8080/
```

### 5.3 Test HPA Auto-scaling

```bash
# Generate load (in one terminal)
kubectl port-forward svc/railconnect-svc 8080:5000 &

# In another terminal, continuously call load endpoint
while true; do curl http://localhost:8080/simulate-load; done

# In a third terminal, watch pods scale up
kubectl get pods -w

# Expected behavior:
# 1. Initial pods: 3 replicas
# 2. CPU usage spikes on each /simulate-load request
# 3. HPA detects CPU > 50%
# 4. New pods are created (up to 30 max)
# 5. Traffic is load-balanced
# 6. Pod name in dashboard changes on each refresh (proving LB works!)
# 7. When load stops, pods scale back down to 3 over 5 minutes
```

---

## Project Files Reference

```
railconnect/
├── app/
│   ├── __init__.py          → Flask app factory
│   ├── routes.py            → All HTTP endpoints
│   ├── mock_data.py         → Fake data generator
│   └── templates/
│       ├── base.html        → Base template
│       ├── index.html       → Dashboard
│       └── schedule.html    → Train schedule
├── tests/
│   ├── test_routes.py       → Endpoint tests
│   └── test_mock_data.py    → Data tests
├── infrastructure/
│   ├── kubernetes/          → K8s manifests
│   └── terraform/           → IaC (Terraform)
├── requirements.txt         → Production dependencies
├── requirements-dev.txt     → Development dependencies
├── Dockerfile               → Production image definition
├── docker-compose.yml       → Full stack (prod)
├── docker-compose.override.yml → Development overrides
├── .dockerignore            → Docker build exclusions
├── .env.example             → Environment template
├── .gitignore              → Git exclusions
├── run.py                   → Flask dev runner
├── Makefile                 → Shortcuts (make run, make test, etc.)
└── README.md               → This guide
```

---

## Common Commands

### Make (Shortcuts)
```bash
make run           # Start Flask dev server
make test          # Run pytest
make lint          # Run flake8
make format        # Format with black
make install       # Install all dependencies
make docker-build  # Build Docker image
make docker-run    # Run Docker container
make help          # Show all available commands
```

### Docker
```bash
docker build -t railconnect:latest .                    # Build image
docker run -p 5000:5000 railconnect:latest             # Run container
docker-compose up -d                                    # Start full stack
docker-compose logs -f app                              # View logs
docker-compose down -v                                  # Stop & clean
```

### Kubernetes
```bash
kubectl apply -f infrastructure/kubernetes/             # Deploy
kubectl get pods                                        # List pods
kubectl logs -f deployment/railconnect-app              # View logs
kubectl scale deployment railconnect-app --replicas=5  # Scale manually
kubectl port-forward svc/railconnect-svc 8080:5000     # Local access
```

---

## Troubleshooting

### Docker Build Fails
```bash
# Check Docker daemon
docker ps

# Build with verbose output
docker build -t railconnect:latest . --progress=plain

# Check disk space
docker system df

# Clean up dangling images
docker image prune -f
```

### Docker Compose Issues
```bash
# Check service logs
docker-compose logs postgres  # or redis, app

# Verify network
docker network ls
docker network inspect railconnect_railconnect-network

# Recreate containers
docker-compose up -d --force-recreate

# Full cleanup
docker-compose down -v && docker-compose up -d
```

### Kubernetes Pod Crashes
```bash
# Check pod status
kubectl describe pod <pod-name>

# View pod logs
kubectl logs <pod-name>

# Check events
kubectl get events --sort-by='.lastTimestamp'

# Debug shell access
kubectl exec -it <pod-name> -- /bin/sh
```

---

## Performance Tuning

### Gunicorn Workers
- Edit `Dockerfile`: `--workers 4` (adjust based on CPU cores)
- Default: 4 workers per container
- Formula: `(2 × CPU_cores) + 1`

### Connection Pool
- Edit `docker-compose.yml`: Postgres `max_connections` parameter
- Default: PostgreSQL 100, Redis connections unlimited

### HPA Thresholds
- Edit `infrastructure/kubernetes/hpa/railconnect-hpa.yaml`
- CPU threshold: 50% (scale up at 50% utilization)
- Memory threshold: 80% (optional addition)

---

## Next Steps

1. ✅ **Local Development** → Use `python run.py`
2. ✅ **Docker Development** → Use `docker-compose up -d`
3. ⏭️ **Push to Registry** → `docker push <registry>/railconnect:v1`
4. ⏭️ **Deploy to EKS** → `kubectl apply -f infrastructure/kubernetes/`
5. ⏭️ **Set up Jenkins CI/CD** → Configure Jenkins pipeline to automate steps 3-4
6. ⏭️ **Monitor & Alert** → Prometheus + Grafana for observability

---

**Last Updated:** June 14, 2026  
**Version:** 1.0.0  
**Status:** Production Ready ✅



