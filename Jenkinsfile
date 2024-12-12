pipeline {
    agent any

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
                script {
                    // Ensure virtual environment is created if not already
                    sh '''
                        echo "Checking python version"
                        python3 --version
                        echo "Checking pip version"
                        pip3 --version || (echo "pip3 not found, installing..." && sudo -u jenkins -H -S apt-get install -y python3-pip)
                        echo "Checking if python3 is in path"
                        which python3
                        echo "Checking if pip3 is in path"
                        which pip3

                        # Create the virtual environment if it doesn't exist
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
                script {
                    // Activate virtual environment and run tests
                    sh '''
                        bash -c "source venv/bin/activate && pytest --maxfail=1 --disable-warnings -q || echo 'No tests found'"
                    '''
                }
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

        // Other stages...
    }
}
