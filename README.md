# RailConnect Transportation Authority

A complete DevOps pipeline implementation for a Flask-based train scheduling and management system with full infrastructure automation, CI/CD integration, and Kubernetes orchestration.

## 🚀 Quick Start

### Prerequisites
- Python 3.9+
- Docker & Docker Compose
- Git
- kubectl (for Kubernetes deployment)
- Terraform (for infrastructure provisioning)
- Jenkins (for CI/CD pipeline)

### Local Development Setup

```bash
# Clone and navigate
cd railconnect

# Create virtual environment
python -m venv .venv
source .venv/bin/activate  # macOS/Linux
# or
.venv\Scripts\activate  # Windows

# Install dependencies
pip install -r requirements.txt

# Set up environment
cp .env.example .env

# Run Flask app
python -m flask run
```

The application will be available at `http://localhost:5000`

---

## 📋 Project Structure

```
railconnect/
├── app/                           # Flask application
│   ├── __init__.py               # App factory (create_app)
│   ├── routes.py                 # All URL routes & views
│   ├── mock_data.py              # Fake data (no database)
│   ├── templates/                # Jinja2 HTML templates
│   │   ├── base.html             # Base layout
│   │   ├── index.html            # Dashboard
│   │   └── schedule.html         # Train schedule
│   └── static/
│       ├── css/                  # Stylesheets
│       └── js/                   # Client-side scripts
│
├── tests/                         # pytest test suite
│   ├── test_routes.py            # Endpoint tests
│   └── test_mock_data.py         # Data function tests
│
├── infrastructure/                # Infrastructure as Code
│   ├── terraform/
│   │   ├── modules/              # Reusable IaC modules
│   │   │   ├── vpc/              # VPC configuration
│   │   │   ├── eks/              # EKS cluster
│   │   │   └── rds/              # Database
│   │   └── environments/
│   │       ├── staging/          # Staging config
│   │       └── production/       # Production config
│   └── kubernetes/               # K8s manifests
│       ├── deployments/
│       │   └── railconnect-app.yaml
│       ├── hpa/
│       │   └── railconnect-hpa.yaml
│       └── ingress/
│           └── railconnect-ingress.yaml
│
├── jenkins/                       # CI/CD pipeline
│   ├── Jenkinsfile               # Pipeline definition
│   └── scripts/
│       ├── build.sh              # Build & test
│       └── deploy.sh             # Deploy to K8s
│
├── Dockerfile                     # Multi-stage Docker build
├── docker-compose.yml            # Local stack (app+Redis+Postgres)
├── docker-compose.override.yml   # Local overrides
├── .gitignore                     # Git exclusions
├── .env.example                   # Environment template
└── README.md                      # This file
```

---

## 🐳 Docker & Docker Compose

### Build Docker Image
```bash
docker build -t railconnect:latest .
```

### Run with Docker Compose (Full Stack)
```bash
# Start all services
docker-compose up -d

# Services started:
# - Flask app on port 5000
# - Redis on port 6379
# - PostgreSQL on port 5432

# View logs
docker-compose logs -f

# Stop services
docker-compose down
```

---

## 🧪 Testing

### Run Tests with pytest
```bash
# Install test dependencies
pip install pytest pytest-cov

# Run all tests
pytest

# Run with coverage report
pytest --cov=app tests/

# Run specific test file
pytest tests/test_routes.py -v
```

---

## 🔧 CI/CD Pipeline (Jenkins)

### Pipeline Stages
1. **Checkout** — Clone repository
2. **Build** — Install dependencies, lint code
3. **Test** — Run pytest suite
4. **Security Scan** — SAST/dependency check
5. **Build Image** — Docker build & push to registry
6. **Deploy Staging** — Deploy to staging K8s cluster
7. **Approval** — Manual approval gate
8. **Deploy Production** — Canary → rolling update

### Run Jenkins Pipeline
```bash
# Trigger via webhook or manually in Jenkins UI
# Pipeline defined in: Jenkinsfile

# View pipeline: Jenkins Dashboard → RailConnect → Build History
```

---

## ☸️ Kubernetes Deployment

### Prerequisites
- EKS cluster provisioned (via Terraform)
- kubectl configured
- Docker image pushed to ECR

### Deploy to K8s
```bash
# Apply manifests
kubectl apply -f infrastructure/kubernetes/

# Check deployment
kubectl get deployments
kubectl get pods

# View HPA status
kubectl get hpa

# Port forward to test
kubectl port-forward svc/railconnect-svc 5000:5000
```

### Manifest Details
- **Deployment** — 3–30 replicas, rolling updates
- **HPA** — Auto-scale on CPU (50–80%)
- **Ingress** — External access routing
- **Service** — Internal load balancing

---

## 🌍 Infrastructure Provisioning (Terraform)

### Provision AWS Resources
```bash
cd infrastructure/terraform/environments/production

# Initialize Terraform
terraform init

# Plan changes
terraform plan -out=railconnect.tfplan

# Apply configuration
terraform apply railconnect.tfplan

# Outputs: VPC ID, EKS cluster endpoint, RDS endpoint
```

### Modules Available
- **VPC** — Networking (subnets, security groups)
- **EKS** — Kubernetes cluster (control plane)
- **RDS** — PostgreSQL database

---

## 🔐 Environment Variables

Copy `.env.example` to `.env` and configure:

```env
# Flask
FLASK_ENV=development
FLASK_APP=app
SECRET_KEY=your-secret-key

# Redis
REDIS_URL=redis://localhost:6379/0

# Database
DATABASE_URL=postgresql://user:password@localhost:5432/railconnect

# Kubernetes
POD_NAME=railconnect-app
SERVICE_PORT=5000
REPLICAS=3
```

⚠️ **Never commit `.env` to version control!**

---

## 📊 Monitoring & Logging

### Local Development
```bash
# Flask development server logs
# Visible in terminal output

# Docker container logs
docker-compose logs -f app
```

### Kubernetes Production
```bash
# Pod logs
kubectl logs -f deployment/railconnect-app

# Describe pod for events
kubectl describe pod <pod-name>

# Stream live logs from all pods
kubectl logs -f -l app=railconnect
```

---

## 🚀 Deployment Workflow

```
1. Developer pushes code to main/develop
   ↓
2. Jenkins webhook triggers pipeline
   ↓
3. Automated tests run
   ↓
4. Docker image built and pushed to ECR
   ↓
5. Image deployed to staging K8s
   ↓
6. Manual approval gate
   ↓
7. Canary deployment to production (5% traffic)
   ↓
8. Monitor metrics (error rate, latency)
   ↓
9. Rolling update if healthy (100% traffic)
```

---

## 🔍 Troubleshooting

### Flask App Won't Start
```bash
# Check Python version
python --version

# Verify virtual environment is activated
which python

# Check dependencies
pip list | grep Flask
```

### Docker Build Fails
```bash
# Check Docker daemon
docker ps

# Build with verbose output
docker build -t railconnect:latest . --progress=plain
```

### K8s Deployment Issues
```bash
# Check pod status
kubectl get pods -o wide

# Describe failing pod
kubectl describe pod <pod-name>

# Check recent events
kubectl get events --sort-by='.lastTimestamp'
```

### Test Failures
```bash
# Run tests with verbose output
pytest -vv tests/

# Run specific test
pytest tests/test_routes.py::test_index -v
```

---

## 📚 Documentation References

- [Flask Documentation](https://flask.palletsprojects.com/)
- [Docker Documentation](https://docs.docker.com/)
- [Kubernetes Docs](https://kubernetes.io/docs/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Jenkins Pipeline](https://www.jenkins.io/doc/book/pipeline/)

---

## 🤝 Contributing

1. Create feature branch: `git checkout -b feature/your-feature`
2. Commit changes: `git commit -am 'Add feature'`
3. Push branch: `git push origin feature/your-feature`
4. Create Pull Request

---

## 📝 License

RailConnect Transportation Authority © 2026

---

## 👥 Team

**RailConnect DevOps Team**  
- Infrastructure & CI/CD Pipeline
- Full-stack Kubernetes deployment
- Infrastructure as Code (Terraform)

---

## 📞 Support

For issues, documentation, or feature requests:
1. Check existing issues/PRs
2. Review troubleshooting section above
3. Contact DevOps team


