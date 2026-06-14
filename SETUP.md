# RailConnect — Complete Setup Guide (Fresh Machine)

This guide walks through every phase from a brand-new machine to a fully running DevOps stack.

---

## Phase 0 — Install Prerequisites

### Git

**macOS**
```bash
xcode-select --install
```

**Ubuntu/Debian**
```bash
sudo apt update && sudo apt install -y git
```

**Windows** — Download from https://git-scm.com/download/win

```bash
git --version   # verify
```

---

### Python 3.9+

**macOS**
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install python@3.9
```

**Ubuntu/Debian**
```bash
sudo apt update && sudo apt install -y python3.9 python3.9-venv python3-pip
```

**Windows** — Download from https://www.python.org/downloads/ (check "Add Python to PATH")

```bash
python3 --version   # verify
```

---

### Docker & Docker Compose

**macOS / Windows** — Install Docker Desktop from https://www.docker.com/products/docker-desktop/
Docker Compose is bundled inside Docker Desktop.

**Ubuntu/Debian**
```bash
sudo apt update
sudo apt install -y ca-certificates curl gnupg

curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update && sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
sudo usermod -aG docker $USER
newgrp docker
```

```bash
docker --version          # verify
docker compose version    # verify
```

---

### kubectl (for Kubernetes phases)

**macOS**
```bash
brew install kubectl
```

**Ubuntu/Debian**
```bash
curl -LO "https://dl.k8s.io/release/$(curl -sL https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
```

**Windows** — `winget install -e --id Kubernetes.kubectl`

```bash
kubectl version --client   # verify
```

---

### Terraform (for AWS provisioning phase)

**macOS**
```bash
brew tap hashicorp/tap && brew install hashicorp/tap/terraform
```

**Ubuntu/Debian**
```bash
sudo apt install -y gnupg software-properties-common
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
  | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform
```

```bash
terraform -version   # verify
```

---

## Phase 1 — Get the Code

```bash
git clone <your-repo-url> railconnect
cd railconnect
```

---

## Phase 2 — Run Locally (Python only)

Best for development. No Docker needed.

```bash
# Create virtual environment
python3 -m venv .venv

# Activate it
source .venv/bin/activate        # macOS/Linux
# .venv\Scripts\activate         # Windows

# Install all dependencies
pip install -r requirements.txt -r requirements-dev.txt

# Set up environment file
cp .env.example .env

# Run tests to verify setup
pytest tests/ -v

# Start the app
python run.py
```

App is live at **http://localhost:5003**

---

## Phase 3 — Docker (Single Container)

```bash
# Build the image
docker build -t railconnect:latest .

# Run it
docker run -d \
  --name railconnect-app \
  -p 5003:5000 \
  -e POD_NAME=docker-local \
  -e FLASK_ENV=production \
  railconnect:latest

# Check it's running
docker ps

# View logs
docker logs -f railconnect-app

# Test health endpoint
curl http://localhost:5003/health

# Stop and remove
docker stop railconnect-app && docker rm railconnect-app
```

---

## Phase 4 — Docker Compose (Full Stack)

Starts Flask app + Redis + PostgreSQL together.

```bash
# Set up environment file (if not done already)
cp .env.example .env

# Build and start all services
docker compose up --build -d

# Check all services are healthy
docker compose ps

# View live logs
docker compose logs -f

# Test the app
curl http://localhost:5003/health
```

Expected output from `docker compose ps`:
```
NAME                    STATUS           PORTS
railconnect-app         Up (healthy)     0.0.0.0:5003->5000/tcp
railconnect-redis       Up (healthy)     0.0.0.0:6379->6379/tcp
railconnect-postgres    Up (healthy)     0.0.0.0:5432->5432/tcp
```

Stop everything:
```bash
docker compose down          # stop containers
docker compose down -v       # stop + wipe volumes
```

---

## Phase 5 — Kubernetes (Local with minikube)

Use this to demo K8s locally without AWS.

### Install minikube

**macOS**
```bash
brew install minikube
```

**Linux**
```bash
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube
```

**Windows** — `winget install minikube`

### Start the cluster

```bash
minikube start --cpus=2 --memory=4096
minikube status   # verify
```

### Update the image name

Open `infrastructure/kubernetes/deployments/railconnect-app.yaml` and replace:
```
image: your-dockerhub-username/railconnect:latest
```
with your actual Docker Hub username, or load the local image:
```bash
minikube image load railconnect:latest
# then set imagePullPolicy: Never in the deployment YAML
```

### Deploy everything

```bash
# Create namespaces first
kubectl apply -f infrastructure/kubernetes/namespaces/

# Deploy app, service, and HPA
kubectl apply -f infrastructure/kubernetes/deployments/
kubectl apply -f infrastructure/kubernetes/services/
kubectl apply -f infrastructure/kubernetes/hpa/

# Check deployment
kubectl get deployments -n railconnect-prod
kubectl get pods -n railconnect-prod
kubectl get hpa -n railconnect-prod
```

### Access the app

```bash
kubectl port-forward svc/railconnect-app 8080:80 -n railconnect-prod
# App available at http://localhost:8080
```

### Test HPA auto-scaling

```bash
# Terminal 1 — forward traffic
kubectl port-forward svc/railconnect-app 8080:80 -n railconnect-prod

# Terminal 2 — generate CPU load
while true; do curl http://localhost:8080/simulate-load; done

# Terminal 3 — watch pods scale up
kubectl get pods -n railconnect-prod -w
kubectl get hpa -n railconnect-prod -w
```

Pods will scale from 3 → up to 30 as CPU crosses 50%. Pod name in the JSON response changes, proving load balancing works.

### Rollback a deployment

```bash
kubectl rollout undo deployment/railconnect-app -n railconnect-prod
kubectl rollout status deployment/railconnect-app -n railconnect-prod
```

---

## Phase 6 — Jenkins CI/CD Pipeline

### Run Jenkins locally with Docker

```bash
docker run -d \
  --name jenkins \
  -p 8080:8080 -p 50000:50000 \
  -v jenkins_home:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  jenkins/jenkins:lts

# Get initial admin password
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

Open **http://localhost:8080**, paste the password, install suggested plugins.

### Configure credentials

In Jenkins → Manage Jenkins → Credentials → Global → Add Credentials:

| Kind | ID | Value |
|---|---|---|
| Username with password | `dockerhub-credentials` | Your Docker Hub login |

### Create the pipeline job

1. New Item → Pipeline → name it `railconnect`
2. Pipeline → Definition → Pipeline script from SCM
3. SCM → Git → paste your repo URL
4. Script Path → `Jenkinsfile`
5. Save → Build Now

### Pipeline stages

The `Jenkinsfile` runs these stages automatically:

```
Checkout → Unit Tests → Code Quality → Security Scan →
Build Docker Image → Push to Registry (main branch only) →
Deploy Staging (develop branch) → Approval Gate → Deploy Production
```

### Run build script manually (without Jenkins)

```bash
bash jenkins/scripts/build.sh . staging 1
```

---

## Phase 7 — Terraform (AWS Infrastructure)

> Requires AWS CLI configured with credentials (`aws configure`)

### Install AWS CLI

```bash
# macOS
brew install awscli

# Linux
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip && sudo ./aws/install

aws configure   # enter Access Key, Secret Key, region (ap-south-1)
```

### Provision staging infrastructure

```bash
cd infrastructure/terraform/environments/staging

terraform init
terraform plan -out=railconnect.tfplan
terraform apply railconnect.tfplan
```

### Provision production infrastructure

```bash
cd infrastructure/terraform/environments/production

terraform init
terraform plan -out=railconnect.tfplan
terraform apply railconnect.tfplan
```

Outputs: VPC ID, EKS cluster endpoint, RDS endpoint.

### Connect kubectl to EKS

```bash
aws eks update-kubeconfig \
  --region ap-south-1 \
  --name railconnect-prod

kubectl get nodes   # verify connection
```

### Destroy infrastructure when done

```bash
terraform destroy   # run inside each environment folder
```

---

## Phase 8 — Run Tests

```bash
# Activate virtual environment first
source .venv/bin/activate

# Run all tests
pytest tests/ -v

# With coverage report
pytest --cov=app tests/

# Quick one-liner via Makefile
make test
```

---

## Verify Everything Works

Once the app is running (any phase), test these endpoints:

| Endpoint | Expected |
|---|---|
| http://localhost:5003/ | Dashboard HTML |
| http://localhost:5003/schedule | Schedule HTML |
| http://localhost:5003/health | `{"status": "healthy", ...}` |
| http://localhost:5003/ready | `{"status": "ready", ...}` |
| http://localhost:5003/api/status | JSON system status |
| http://localhost:5003/api/stats | JSON ticket stats |
| http://localhost:5003/simulate-load | CPU spike for HPA testing |
| http://localhost:5003/metrics | Prometheus metrics |

Quick check:
```bash
curl http://localhost:5003/health
```

---

## Makefile Shortcuts

```bash
make run           # Start Flask dev server
make test          # Run pytest with coverage
make lint          # Run flake8
make format        # Format with black
make install       # Install all dependencies
make docker-build  # Build Docker image
make docker-run    # Run Docker container
make help          # List all commands
```

---

## Troubleshooting

**Port 5003 already in use**
```bash
lsof -i :5003          # macOS/Linux — find the PID
kill -9 <PID>
```

**Docker containers not starting**
```bash
docker compose logs app
docker compose logs postgres
docker compose logs redis
docker compose up -d --force-recreate
```

**Virtual env not activating on Windows**
```bash
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
.venv\Scripts\Activate.ps1
```

**K8s pods crashing (ImagePullBackOff)**
```bash
kubectl describe pod <pod-name> -n railconnect-prod
# Update image name in deployments/railconnect-app.yaml to your Docker Hub username
```

**K8s pods not scaling (HPA shows `<unknown>`)**
```bash
# metrics-server must be running
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl get hpa -n railconnect-prod
```

**Terraform apply fails (AWS auth)**
```bash
aws sts get-caller-identity   # verify credentials work
aws configure                  # reconfigure if needed
```

**Tests failing with import errors**
```bash
pip install -r requirements-dev.txt
```
