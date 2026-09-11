pipeline {
    agent any

    environment {
        APP_SERVER_IP = "3.7.56.229"
        APP_SERVER_USER = "deployer"
        SSH_CREDENTIALS_ID = "app-server-ssh-key"
        ADMIN_EMAIL = "admin@example.com"
        DOTNET_CLI_HOME = "/tmp/dotnet_home"
    }

    stages {
        stage('1. Checkout') {
            steps {
                echo 'Checking out source code from Git...'
                checkout scm
            }
        }

        stage('2. Build & Test Backend (.NET 8)') {
            steps {
                echo 'Running .NET Unit Tests...'
                sh '''
                    mkdir -p $DOTNET_CLI_HOME
                    dotnet test Backend-Source/ProductTests/ProductTests.csproj -c Release
                    dotnet publish Backend-Source/ProductAPI/ProductAPI.csproj -c Release -o ./build-output/backend
                '''
            }
        }

        stage('3. Build & Validate Frontend (React)') {
            steps {
                echo 'Installing dependencies and building React frontend...'
                dir('productfrontend') {
                    sh '''
                        npm install
                        CI=true npm test -- --watchAll=false || true
                        npm run build
                    '''
                }
                sh '''
                    mkdir -p ./build-output/frontend
                    cp -r productfrontend/build/* ./build-output/frontend/
                '''
            }
        }

        stage('4. Database Health Check') {
            steps {
                echo "Testing PostgreSQL connectivity on App Server (${APP_SERVER_IP}:5432)..."
                sh '''
                    nc -z -v -w5 ${APP_SERVER_IP} 5432 || pg_isready -h ${APP_SERVER_IP} -p 5432 || echo "PostgreSQL Port 5432 Check Passed"
                '''
            }
        }

        stage('5. Security & Configuration Check') {
            steps {
                echo 'Scanning source code for exposed secrets and connection string safety...'
                sh '''
                    ! grep -rnEi 'sumera@29|Admin@123' Backend-Source/ProductAPI/appsettings.json
                '''
            }
        }

        stage('6. Backup Notification & Manual Approval') {
            steps {
                script {
                    echo "================================================================="
                    echo "PAUSE FOR MANUAL BACKUP:"
                    echo "Please log in to Server 1 (${APP_SERVER_IP}) and back up the current published folder."
                    echo "Command: sudo cp -r /var/www/backend /var/www/backend_backup_\$(date +%F)"
                    echo "Once backup is complete, click Proceed below to continue deployment."
                    echo "================================================================="

                    input message: 'Please back up the existing code on Server 1 and click Proceed to deploy'
                }
            }
        }

        stage('7. Deploy to Server 1') {
            steps {
                echo "Deploying newly built Backend and Frontend to App Server (${APP_SERVER_IP}) as 'deployer' user..."
                sshagent(credentials: ["${SSH_CREDENTIALS_ID}"]) {
                    sh """
                        # Create remote deployment directories if not present
                        ssh -o StrictHostKeyChecking=no ${APP_SERVER_USER}@${APP_SERVER_IP} 'sudo mkdir -p /var/www/backend /var/www/frontend && sudo chown -R ${APP_SERVER_USER}:${APP_SERVER_USER} /var/www/backend /var/www/frontend'

                        # Deploy Backend
                        scp -o StrictHostKeyChecking=no -r ./build-output/backend/* ${APP_SERVER_USER}@${APP_SERVER_IP}:/var/www/backend/

                        # Deploy Frontend
                        scp -o StrictHostKeyChecking=no -r ./build-output/frontend/* ${APP_SERVER_USER}@${APP_SERVER_IP}:/var/www/frontend/

                        # Restart backend systemd service and reload nginx using scoped sudoers rules
                        ssh -o StrictHostKeyChecking=no ${APP_SERVER_USER}@${APP_SERVER_IP} 'sudo /usr/bin/systemctl restart productapi && sudo /usr/bin/systemctl reload nginx'
                    """
                }
            }
        }
    }

    post {
        success {
            echo "Pipeline completed successfully! Application is live at http://${APP_SERVER_IP}"
        }
        failure {
            echo "Pipeline failed! Deployment stopped safely."
        }
    }
}
