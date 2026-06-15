// Jenkinsfile - RailConnect CI/CD Pipeline
// Full 7-stage pipeline: Checkout → Test → Security Scan → Build → Deploy Staging → Approval → Deploy Production
// Supports: GitHub webhooks, multi-branch pipelines, Blue Ocean visualization

pipeline {
    agent any

    environment {
        // Docker Hub Configuration
        DOCKERHUB_CREDENTIALS = credentials('dockerhub-credentials')
        DH_USER = "${DOCKERHUB_CREDENTIALS_USR}"
        DH_PASS = "${DOCKERHUB_CREDENTIALS_PSW}"
        
        // Application Configuration
        APP_NAME = "railconnect"
        GITHUB_REPO = "hitarth2123/RailConnect"
        AWS_REGION = "ap-south-1"
        
        // Image tagging: branch-commit-buildnumber
        TAG = "${env.GIT_BRANCH.replaceAll('/', '-')}-${env.GIT_COMMIT.take(7)}-${env.BUILD_NUMBER}"
        IMAGE_NAME = "${DH_USER}/${APP_NAME}"
        IMAGE_FULL = "${IMAGE_NAME}:${TAG}"
        IMAGE_LATEST = "${IMAGE_NAME}:latest"
    }

    options {
        buildDiscarder(logRotator(numToKeepStr: '15'))
        timeout(time: 45, unit: 'MINUTES')
        timestamps()
        disableConcurrentBuilds()
    }

    triggers {
        // Webhook from GitHub on push and PR
        githubPush()
        // Poll every 15 minutes if no webhook
        pollSCM('H/15 * * * *')
    }

    stages {
        stage('Checkout') {
            steps {
                script {
                    echo "═══════════════════════════════════════════"
                    echo "STAGE 1: CHECKOUT"
                    echo "═══════════════════════════════════════════"
                    echo "Branch: ${env.GIT_BRANCH}"
                    echo "Commit: ${env.GIT_COMMIT.take(7)}"
                    echo "Build: #${env.BUILD_NUMBER}"
                    echo "Workspace: ${env.WORKSPACE}"
                }
                checkout scm
            }
        }

        stage('Unit Tests') {
            steps {
                script {
                    echo "═══════════════════════════════════════════"
                    echo "STAGE 2: UNIT TESTS"
                    echo "═══════════════════════════════════════════"
                }
                sh '''
                    set -e
                    python3 -m venv .venv
                    . .venv/bin/activate
                    pip install -r requirements.txt -r requirements-dev.txt -q
                    
                    echo "Running pytest..."
                    pytest tests/ -v \
                        --tb=short \
                        --junit-xml=test-results.xml \
                        --cov=app \
                        --cov-report=xml \
                        --cov-report=term-missing
                    
                    echo "✓ All tests passed"
                '''
            }
            post {
                always {
                    junit 'test-results.xml'
                    archiveArtifacts artifacts: 'coverage.xml', allowEmptyArchive: true
                }
            }
        }

        stage('Code Quality') {
            steps {
                script {
                    echo "═══════════════════════════════════════════"
                    echo "STAGE 3: CODE QUALITY & LINTING"
                    echo "═══════════════════════════════════════════"
                }
                sh '''
                    . .venv/bin/activate
                    
                    echo "Running flake8 linting..."
                    flake8 app/ --max-line-length=100 --exit-zero || true
                    
                    echo "Checking black formatting..."
                    black --check app/ tests/ || true
                    
                    echo "✓ Code quality checks complete"
                '''
            }
        }

        stage('Security Scan') {
            steps {
                script {
                    echo "═══════════════════════════════════════════"
                    echo "STAGE 4: SECURITY SCANNING"
                    echo "═══════════════════════════════════════════"
                }
                sh '''
                    . .venv/bin/activate
                    
                    # Check for vulnerable dependencies
                    pip install bandit -q
                    echo "Running Bandit security scan..."
                    bandit -r app/ -f json -o bandit-report.json || true
                    
                    echo "✓ Security scan complete"
                '''
            }
            post {
                always {
                    archiveArtifacts artifacts: 'bandit-report.json', allowEmptyArchive: true
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    echo "═══════════════════════════════════════════"
                    echo "STAGE 5: BUILD DOCKER IMAGE"
                    echo "═══════════════════════════════════════════"
                    echo "Image: ${IMAGE_FULL}"
                }
                sh '''
                    set -e
                    
                    echo "Building Docker image..."
                    docker build -t ${IMAGE_FULL} -t ${IMAGE_LATEST} .
                    
                    echo "Image built successfully"
                    docker images | grep ${APP_NAME}
                '''
            }
        }

        stage('Push to Registry') {
            when {
                branch 'main'
            }
            steps {
                script {
                    echo "═══════════════════════════════════════════"
                    echo "STAGE 6: PUSH TO DOCKER HUB"
                    echo "═══════════════════════════════════════════"
                }
                sh '''
                    set -e
                    
                    echo "Logging into Docker Hub..."
                    echo "${DH_PASS}" | docker login -u "${DH_USER}" --password-stdin
                    
                    echo "Pushing ${IMAGE_FULL}..."
                    docker push ${IMAGE_FULL}
                    
                    echo "Pushing ${IMAGE_LATEST}..."
                    docker push ${IMAGE_LATEST}
                    
                    docker logout
                    echo "✓ Images pushed to Docker Hub"
                '''
            }
        }

        stage('Deploy to Staging') {
            when {
                branch 'develop'
            }
            steps {
                script {
                    echo "═══════════════════════════════════════════"
                    echo "STAGE 7: DEPLOY TO STAGING"
                    echo "═══════════════════════════════════════════"
                }
                sh '''
                    set -e
                    
                    # Configure kubectl
                    aws eks update-kubeconfig \
                        --region ${AWS_REGION} \
                        --name railconnect-staging
                    
                    # Update deployment image
                    kubectl set image deployment/railconnect-app \
                        railconnect-app=${IMAGE_FULL} \
                        -n railconnect-staging \
                        --record
                    
                    # Wait for rollout
                    kubectl rollout status deployment/railconnect-app \
                        -n railconnect-staging \
                        --timeout=5m
                    
                    echo "✓ Deployed to staging successfully"
                '''
            }
        }

        stage('Approval for Production') {
            when {
                branch 'main'
            }
            steps {
                script {
                    echo "═══════════════════════════════════════════"
                    echo "STAGE 8: MANUAL APPROVAL REQUIRED"
                    echo "═══════════════════════════════════════════"
                    
                    timeout(time: 30, unit: 'MINUTES') {
                        input message: 'Deploy to Production?', ok: 'Deploy'
                    }
                }
            }
        }

        stage('Deploy to Production') {
            when {
                branch 'main'
            }
            steps {
                script {
                    echo "═══════════════════════════════════════════"
                    echo "STAGE 9: DEPLOY TO PRODUCTION"
                    echo "═══════════════════════════════════════════"
                }
                sh '''
                    set -e
                    
                    # Configure kubectl for production
                    aws eks update-kubeconfig \
                        --region ${AWS_REGION} \
                        --name railconnect-prod
                    
                    # Rolling update with zero downtime
                    kubectl set image deployment/railconnect-app \
                        railconnect-app=${IMAGE_FULL} \
                        -n railconnect-prod \
                        --record
                    
                    # Wait for rollout with timeout
                    kubectl rollout status deployment/railconnect-app \
                        -n railconnect-prod \
                        --timeout=10m
                    
                    # Verify health
                    sleep 30
                    READY_PODS=$(kubectl get deployment railconnect-app -n railconnect-prod -o jsonpath='{.status.readyReplicas}')
                    DESIRED_PODS=$(kubectl get deployment railconnect-app -n railconnect-prod -o jsonpath='{.spec.replicas}')
                    
                    if [ "$READY_PODS" != "$DESIRED_PODS" ]; then
                        echo "ERROR: Not all pods are ready!"
                        exit 1
                    fi
                    
                    echo "✓ Production deployment successful"
                    echo "Replicas ready: $READY_PODS/$DESIRED_PODS"
                '''
            }
        }
    }

    post {
        always {
            script {
                echo "═══════════════════════════════════════════"
                echo "BUILD SUMMARY"
                echo "═══════════════════════════════════════════"
                echo "Status: ${currentBuild.result}"
                echo "Duration: ${currentBuild.durationString}"
                echo "Branch: ${env.GIT_BRANCH}"
                echo "Image: ${IMAGE_FULL}"
            }
            
            // Cleanup
            sh '''
                docker logout || true
                rm -rf .venv || true
            '''
        }
        
        success {
            script {
                echo "✓ Pipeline completed successfully"
                // TODO: Send Slack notification
                // sh 'curl -X POST -H "Content-type: application/json" --data "..." $SLACK_WEBHOOK'
            }
        }
        
        failure {
            script {
                echo "✗ Pipeline failed"
                // TODO: Send Slack alert
            }
        }
    }
}
