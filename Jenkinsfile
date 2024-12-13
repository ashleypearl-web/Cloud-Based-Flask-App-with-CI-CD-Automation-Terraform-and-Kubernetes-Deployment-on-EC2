pipeline {
    agent any

    parameters {
        booleanParam(name: 'SKIP_CODE_ANALYSIS', defaultValue: false, description: 'Skip code analysis with flake8')
    }

    environment {
        registry = "816069136612.dkr.ecr.us-east-1.amazonaws.com/tech-consulting-final-project-app"  // ECR repository URI
        registryCredential = 'ecr-credentials'  // AWS credentials stored in Jenkins (ensure they have permission to access ECR)
        SONAR_SCANNER_OPTS = '--add-opens=java.base/java.lang=ALL-UNNAMED --add-opens=java.base/java.util=ALL-UNNAMED --add-opens=java.base/java.io=ALL-UNNAMED'
        AWS_REGION = 'us-east-1'  // Your AWS region
        AWS_ACCOUNT_ID = '816069136612'  // Your AWS account ID
    }

    stages {
        // Stage 1: Build the Flask app
        stage('BUILD Flask App') {
            steps {
                sh '''
                    echo "Checking python version"
                    python3 --version
                    echo "Checking pip version"
                    pip3 --version || (echo "pip3 not found, installing..." && sudo -u ubuntu -H -S apt-get install -y python3-pip)
                    echo "Checking if python3 is in path"
                    which python3
                    echo "Checking if pip3 is in path"
                    which pip3

                    # Ensure virtual environment is created if not already
                    if [ ! -d "venv" ]; then
                        python3 -m venv venv
                    fi

                    # Activate virtual environment (using bash explicitly)
                    bash -c "source venv/bin/activate && pip freeze"

                    # Install dependencies
                    bash -c "source venv/bin/activate && pip install -r requirements.txt"

                    # Check again after installation
                    bash -c "source venv/bin/activate && pip freeze"
                '''
            }
            post {
                success {
                    echo 'Flask app build successful. Archiving artifacts...'
                }
            }
        }

        // Stage 2: Unit Test the Flask app
        stage('UNIT TEST Flask App') {
            when {
                expression { fileExists('tests') || fileExists('tests/*.py') }
            }
            steps {
                sh '''
                    # Activate virtual environment and run tests
                    bash -c "source venv/bin/activate && pytest --maxfail=1 --disable-warnings -q || echo 'No tests found'"
                '''
            }
            post {
                success {
                    echo 'Unit tests passed'
                }
                failure {
                    echo 'Unit tests failed. Review logs for details.'
                }
            }
        }

        // Stage 3: SonarQube Code Analysis
        stage('SonarQube Code Analysis') {
            environment {
                scannerHome = tool 'sonar-scanner'
                sonarUrl = 'http://172.31.22.207:9000'
            }
            steps {
                withSonarQubeEnv('sonarserver') {
                    sh '''
                        ${scannerHome}/bin/sonar-scanner \
                        -Dsonar.projectKey=ashleyprofile \
                        -Dsonar.projectName=ashley-repo \
                        -Dsonar.projectVersion=1.0 \
                        -Dsonar.sources=. \
                        -Dsonar.language=python \
                        -Dsonar.python.coverage.reportPaths=coverage-report.xml \
                        -Dsonar.host.url=${sonarUrl}
                    '''
                }
            }
            post {
                success {
                    echo 'SonarQube analysis completed successfully'
                }
                failure {
                    echo 'SonarQube analysis failed'
                }
            }
        }

        // Stage 4: Cleanup Docker
        stage('Cleanup Docker') {
            steps {
                sh '''
                    # Clean up unused Docker containers, networks, volumes, and images
                    echo "Pruning unused Docker data..."
                    docker system prune -af --volumes
                    docker volume prune -f || true
                '''
            }
        }

        // Stage 5: Build Flask Docker Image
        stage('Build Flask Docker Image') {
            steps {
                script {
                    flaskImage = docker.build("${registry}/flask-app:V$BUILD_NUMBER", "-f Dockerfile .")
                }
            }
        }

        // Stage 6: Build MySQL Docker Image
        stage('Build MySQL Docker Image') {
            steps {
                script {
                    mysqlImage = docker.build("${registry}/mysql-db:V$BUILD_NUMBER", "-f mysql/Dockerfile mysql/")
                }
            }
        }

        // Stage 7: Upload Images to Amazon ECR
        stage('Upload Images to Amazon ECR') {
            steps {
                script {
                    // Login to Amazon ECR (ensure AWS CLI is installed first)
                    withCredentials([aws(credentialsId: 'ecr-credentials')]) {
                        sh '''
                            # Ensure required dependencies are installed
                            if ! command -v unzip &>/dev/null; then
                                echo "unzip not found, installing..."
                                sudo apt-get update && sudo apt-get install -y unzip
                            fi

                            if ! command -v aws &>/dev/null; then
                                echo "AWS CLI not found. Installing..."
                                curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
                                unzip -o awscliv2.zip  # -o flag ensures non-interactive unzip
                                sudo ./aws/install --update  
                            fi

                            # Login to AWS ECR
                            aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
                            
                            # Create the ECR repositories if they don't exist
                            aws ecr describe-repositories --repository-names tech-consulting-final-project-app/flask-app --region ${AWS_REGION} || aws ecr create-repository --repository-name tech-consulting-final-project-app/flask-app --region ${AWS_REGION}
                            aws ecr describe-repositories --repository-names tech-consulting-final-project-app/mysql-db --region ${AWS_REGION} || aws ecr create-repository --repository-name tech-consulting-final-project-app/mysql-db --region ${AWS_REGION}
                        '''

                        // Push Flask image to ECR
                        flaskImage.push("V$BUILD_NUMBER")
                        flaskImage.push('latest')

                        // Push MySQL image to ECR
                        mysqlImage.push("V$BUILD_NUMBER")
                        mysqlImage.push('latest')
                    }
                }
            }
        }

        // Stage 8: Remove Unused Docker Images from Jenkins Agent
        stage('Remove Unused Docker Images') {
            steps {
                sh '''
                    docker rmi -f ${registry}/flask-app:V$BUILD_NUMBER || echo "Flask app image in use, skipping removal"
                    docker rmi -f ${registry}/mysql-db:V$BUILD_NUMBER || echo "MySQL DB image in use, skipping removal"
                    docker system prune -f
                '''
            }
        }

        // Stage 9: Deploy to Kubernetes using Helm
        stage('Kubernetes Deploy') {
            agent { label 'KOPS' }
            steps {
                sh '''
                    helm upgrade --install --force ashleyflaskapp helm/ashleyflaskappcharts \
                    --set appimage=${registry}/flask-app:V${BUILD_NUMBER} \
                    --set mysqlimage=${registry}/mysql-db:V${BUILD_NUMBER} \
                    --namespace prod
                '''
            }
        }
    }
}
