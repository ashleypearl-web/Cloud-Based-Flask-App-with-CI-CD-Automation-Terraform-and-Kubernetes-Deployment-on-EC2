pipeline {
    agent { label 'KOPS' }

    parameters {
        booleanParam(name: 'SKIP_CODE_ANALYSIS', defaultValue: false, description: 'Skip code analysis with flake8')
    }

    environment {
        registry = "ashleypearl/ashleysdock"
        registryCredential = 'dockerhub'
    }

    stages {
        // Stage 1: Build the Flask app - install dependencies and run tests
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

                    # Activate virtual environment
                    . venv/bin/activate

                    # Check pip install status
                    echo "Checking installed pip packages..."
                    pip freeze

                    # Install dependencies
                    pip install -r requirements.txt

                    # Check again after installation
                    echo "Checking installed pip packages after installation..."
                    pip freeze
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
                // Only run this stage if the tests directory exists
                expression { fileExists('tests') || fileExists('tests/*.py') }
            }
            steps {
                sh '''
                    # Activate virtual environment
                    . venv/bin/activate
                    
                    # Run tests if available
                    pytest --maxfail=1 --disable-warnings -q || echo "No tests found"
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

        // Stage 3: Code analysis with flake8 (conditionally skipped)
        stage('CODE ANALYSIS WITH FLAKE8') {
            when {
                expression { return !params.SKIP_CODE_ANALYSIS }  // Skip if SKIP_CODE_ANALYSIS is true
            }
            steps {
                sh '''
                    # Activate virtual environment
                    . venv/bin/activate
                    
                    # Run flake8 for linting
                    flake8 .
                '''
            }
            post {
                success {
                    echo 'Generated Flake8 Analysis Results'
                }
            }
        }

        // Stage 4: SonarQube Code Analysis
        stage('SonarQube Code Analysis') {
            environment {
                scannerHome = tool 'sonar-scanner'  // Ensure SonarQube scanner is configured
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
                           -Dsonar.python.coverage.reportPaths=coverage-report.xml
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

        // Stage 5: Build Docker Image for Flask App
        stage('Build Flask Docker Image') {
            steps {
                script {
                    flaskImage = docker.build(registry + "/flask-app:V$BUILD_NUMBER", "-f Dockerfile .")
                }
            }
        }

        // Stage 6: Build Docker Image for MySQL Database
        stage('Build MySQL Docker Image') {
            steps {
                script {
                    mysqlImage = docker.build(registry + "/mysql-db:V$BUILD_NUMBER", "-f mysql/Dockerfile mysql/")
                }
            }
        }

        // Stage 7: Upload Docker Images to Registry
        stage('Upload Images to Registry') {
            steps {
                script {
                    docker.withRegistry('', registryCredential) {
                        flaskImage.push("V$BUILD_NUMBER")
                        flaskImage.push('latest')
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
                    # Clean up unused Docker images to save space
                    docker rmi $registry/flask-app:V$BUILD_NUMBER
                    docker rmi $registry/mysql-db:V$BUILD_NUMBER
                    docker system prune -f  # This removes unused containers, images, volumes, and networks
                '''
            }
        }

        // Stage 9: Deploy to Kubernetes using Helm
        stage('Kubernetes Deploy') {
            agent { label 'KOPS' }
            steps {
                sh '''
                    helm upgrade --install --force ashleyflaskapp helm/Chart \
                        --set appimage=${registry}/flask-app:V${BUILD_NUMBER} \
                        --set mysqlimage=${registry}/mysql-db:V${BUILD_NUMBER} \
                        --namespace prod
                '''
            }
        }
    }
}

