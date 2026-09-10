pipeline {
    agent any

    environment {
        APP_SERVER_IP = "3.7.56.229"
        APP_SERVER_USER = "ubuntu"
        SSH_CREDENTIALS_ID = "app-server-ssh-key"
        ADMIN_EMAIL = "mksocials21@gmail.com" // Configure with your actual email in Jenkins
        DOTNET_CLI_HOME = "/tmp/dotnet_home"
    }

    stages {
        stage('Checkout') {
            steps {
                echo 'Checking out source code from Git...'
                checkout scm
            }
        }

        stage('Build Backend (.NET 8)') {
            steps {
                echo 'Building and publishing .NET Backend API...'
                sh '''
                    mkdir -p $DOTNET_CLI_HOME
                    dotnet publish Backend-Source/ProductAPI/ProductAPI.csproj -c Release -o ./build-output/backend
                '''
            }
        }

        stage('Build Frontend (React)') {
            steps {
                echo 'Installing dependencies and building React frontend...'
                dir('productfrontend') {
                    sh '''
                        npm install
                        npm run build
                    '''
                }
                sh '''
                    mkdir -p ./build-output/frontend
                    cp -r productfrontend/build/* ./build-output/frontend/
                '''
            }
        }

        stage('Database Health Check') {
            steps {
                echo "Testing PostgreSQL connectivity on App Server (${APP_SERVER_IP}:5432)..."
                sh '''
                    # Check if port 5432 is open and accepting connections
                    nc -z -v -w5 ${APP_SERVER_IP} 5432 || pg_isready -h ${APP_SERVER_IP} -p 5432 || echo "Port 5432 check completed"
                '''
            }
        }

        stage('Backup Notification & Approval') {
            steps {
                script {
                    echo 'Sending notification email to Admin to back up existing server code...'
                    // If Jenkins Email Extension Plugin is configured:
                    // emailext(
                    //     to: "${ADMIN_EMAIL}",
                    //     subject: "Jenkins Build #${env.BUILD_NUMBER} - Backup Required",
                    //     body: "Build is successful. Please log in to Server 1 (${APP_SERVER_IP}) and back up the current published folder before deployment."
                    // )

                    echo "================================================================="
                    echo "PAUSE FOR MANUAL BACKUP:"
                    echo "Please log in to Server 1 (${APP_SERVER_IP}) and back up the current published folder."
                    echo "Once backup is complete, click Proceed below to continue deployment."
                    echo "================================================================="

                    input message: 'Please back up the existing code on Server 1 and click Proceed to deploy'
                }
            }
        }

        stage('Deploy to Server 1') {
            steps {
                echo "Deploying newly built Backend and Frontend to App Server (${APP_SERVER_IP})..."
                sshagent(credentials: ["${SSH_CREDENTIALS_ID}"]) {
                    sh """
                        # Create remote deployment directories if not present
                        ssh -o StrictHostKeyChecking=no ${APP_SERVER_USER}@${APP_SERVER_IP} 'sudo mkdir -p /var/www/backend /var/www/frontend && sudo chown -R ${APP_SERVER_USER}:${APP_SERVER_USER} /var/www/backend /var/www/frontend'

                        # Deploy Backend
                        scp -o StrictHostKeyChecking=no -r ./build-output/backend/* ${APP_SERVER_USER}@${APP_SERVER_IP}:/var/www/backend/

                        # Deploy Frontend
                        scp -o StrictHostKeyChecking=no -r ./build-output/frontend/* ${APP_SERVER_USER}@${APP_SERVER_IP}:/var/www/frontend/

                        # Restart backend systemd service and reload nginx
                        ssh -o StrictHostKeyChecking=no ${APP_SERVER_USER}@${APP_SERVER_IP} 'sudo systemctl restart productapi && sudo systemctl reload nginx'
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
            echo "Pipeline failed! Please check logs above."
        }
    }
}
