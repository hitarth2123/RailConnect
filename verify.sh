#!/bin/bash
# RailConnect Project Verification Script
# Tests all components to ensure deployment readiness

set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$PROJECT_DIR/.venv"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "========================================"
echo "RailConnect Verification Script"
echo "========================================"
echo ""

# Check if venv exists
if [ ! -d "$VENV_DIR" ]; then
    echo -e "${YELLOW}⚠ Virtual environment not found${NC}"
    echo "Creating venv..."
    python3.12 -m venv "$VENV_DIR"
    source "$VENV_DIR/bin/activate"
    pip install -q -r requirements.txt -r requirements-dev.txt
else
    source "$VENV_DIR/bin/activate"
fi

echo -e "${GREEN}✓${NC} Virtual environment ready"
echo ""

# Test 1: Check Python version
echo "Test 1: Python Version"
python_version=$(python --version | grep -o 'Python [0-9.]*')
if [[ $python_version == *"3.12"* ]] || [[ $python_version == *"3.9"* ]] || [[ $python_version == *"3.10"* ]] || [[ $python_version == *"3.11"* ]]; then
    echo -e "${GREEN}✓${NC} Python version: $python_version"
else
    echo -e "${YELLOW}⚠${NC} Python version: $python_version (expected 3.9+)"
fi
echo ""

# Test 2: Check dependencies
echo "Test 2: Required Dependencies"
dependencies=("flask" "gunicorn" "prometheus_flask_exporter" "dotenv" "pytest")
for dep in "${dependencies[@]}"; do
    if python -c "import ${dep}" 2>/dev/null; then
        echo -e "${GREEN}✓${NC} $dep installed"
    else
        echo -e "${RED}✗${NC} $dep NOT installed"
    fi
done
echo ""

# Test 3: Run pytest
echo "Test 3: Running Pytest Suite"
cd "$PROJECT_DIR"
pytest_output=$(pytest tests/ -v 2>&1)
if echo "$pytest_output" | grep -q "passed"; then
    passed=$(echo "$pytest_output" | grep -o "[0-9]* passed" | grep -o "[0-9]*")
    echo -e "${GREEN}✓${NC} $passed tests passed"
else
    echo -e "${RED}✗${NC} Tests failed"
    echo "$pytest_output"
fi
echo ""

# Test 4: Flask app imports
echo "Test 4: Flask Application"
if python -c "from app import create_app; app = create_app()" 2>/dev/null; then
    echo -e "${GREEN}✓${NC} Flask app imports successfully"
else
    echo -e "${RED}✗${NC} Flask app import failed"
fi
echo ""

# Test 5: Check key files exist
echo "Test 5: Project Files"
files=(
    "Dockerfile"
    "docker-compose.yml"
    "docker-compose.override.yml"
    ".dockerignore"
    "requirements.txt"
    "requirements-dev.txt"
    "app/__init__.py"
    "app/routes.py"
    "app/mock_data.py"
    "app/templates/base.html"
    "app/templates/index.html"
    "app/templates/schedule.html"
    "tests/test_routes.py"
    "README.md"
    "DEPLOYMENT.md"
)

for file in "${files[@]}"; do
    if [ -f "$file" ]; then
        echo -e "${GREEN}✓${NC} $file"
    else
        echo -e "${RED}✗${NC} $file MISSING"
    fi
done
echo ""

# Test 6: Docker check
echo "Test 6: Docker & Docker Compose"
if command -v docker &> /dev/null; then
    docker_version=$(docker --version | cut -d' ' -f3)
    echo -e "${GREEN}✓${NC} Docker installed: v$docker_version"
else
    echo -e "${YELLOW}⚠${NC} Docker not found (needed for containerization)"
fi

if command -v docker-compose &> /dev/null; then
    compose_version=$(docker-compose --version | cut -d' ' -f3)
    echo -e "${GREEN}✓${NC} Docker Compose installed: v$compose_version"
else
    echo -e "${YELLOW}⚠${NC} Docker Compose not found (needed for full stack)"
fi
echo ""

# Test 7: Kubernetes check
echo "Test 7: Kubernetes Tools"
if command -v kubectl &> /dev/null; then
    kubectl_version=$(kubectl version --client -o json 2>/dev/null | grep -o '"gitVersion":"[^"]*"' | head -1 | cut -d'"' -f4)
    echo -e "${GREEN}✓${NC} kubectl installed: $kubectl_version"
else
    echo -e "${YELLOW}⚠${NC} kubectl not found (needed for K8s deployment)"
fi
echo ""

# Test 8: Makefile targets
echo "Test 8: Available Make Commands"
if [ -f "Makefile" ]; then
    make_targets=$(grep "^[a-zA-Z].*:" Makefile | cut -d':' -f1 | wc -l)
    echo -e "${GREEN}✓${NC} $make_targets make targets available"
    echo "   Run: make help"
else
    echo -e "${YELLOW}⚠${NC} Makefile not found"
fi
echo ""

# Test 9: Endpoint test
echo "Test 9: Flask Endpoints"
echo "Starting Flask app for 5 seconds..."
timeout 5s python run.py > /tmp/flask.log 2>&1 &
FLASK_PID=$!
sleep 2

if curl -s http://localhost:5000/health > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} /health endpoint responding"
else
    echo -e "${YELLOW}⚠${NC} /health endpoint not responding (Flask may not be running)"
fi

if curl -s http://localhost:5000/ > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} / endpoint responding"
else
    echo -e "${YELLOW}⚠${NC} / endpoint not responding"
fi

# Kill Flask if still running
kill $FLASK_PID 2>/dev/null || true
wait $FLASK_PID 2>/dev/null || true
echo ""

# Summary
echo "========================================"
echo "Verification Complete!"
echo "========================================"
echo ""
echo "Next steps:"
echo "1. Local development:  python run.py"
echo "2. Run tests:          pytest tests/ -v"
echo "3. Docker build:       docker build -t railconnect:latest ."
echo "4. Full stack:         docker-compose up -d"
echo "5. Deploy to K8s:      kubectl apply -f infrastructure/kubernetes/"
echo ""
echo "For more information, see:"
echo "  - README.md (project overview)"
echo "  - DEPLOYMENT.md (comprehensive guide)"
echo "  - PROJECT_SUMMARY.md (detailed status)"
echo ""

deactivate
