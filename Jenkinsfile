pipeline {
    agent any

    tools {
        terraform 'terraform'
    }

    parameters {
        choice(name: 'action', choices: ['apply', 'destroy'], description: 'Select the action to perform')
    }

    triggers {
        pollSCM('* * * * *') // Runs every minute
    }

    environment {
        SLACKCHANNEL = '3rd-november-2025-pet-adoption-auto-discovery-project-eu-team'
        SLACKCREDENTIALS = credentials('slack')
    }

    stages {
        stage('IAC Scan') {
            steps {
                script {
                    sh 'pip install pipenv'
                    sh 'pipenv run pip install checkov'
                    def checkovStatus = sh(script: 'pipenv run checkov -d . -o cli --output-file checkov-results.txt --quiet', returnStatus: true)
                    junit allowEmptyResults: true, testResults: 'checkov-results.txt' 
                }
            }
        }

        stage('Terraform Init') {
            steps {
                sh 'terraform init'
            }
        }

        stage('Terraform Format') {
            steps {
                sh 'terraform fmt --recursive'
            }
        }

        stage('Terraform Validate') {
            steps {
                sh 'terraform validate'
            }
        }

        stage('Terraform Plan') {
            steps {
                sh 'terraform plan'
            }
        }

        stage('Terraform Action') {
            steps {
                script {
                    sh "terraform ${params.action} -auto-approve"
                }
            }
        }
    }

    post {
        always {
            script {
                slackSend(
                    channel: env.SLACKCHANNEL,
                    tokenCredentialId: env.SLACKCREDENTIALS,
                    color: currentBuild.result == 'SUCCESS' ? 'good' : 'danger',
                    message: "Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]' (${env.BUILD_URL}) has been completed."
                )
            }
        }
        failure {
            slackSend(
                channel: env.SLACKCHANNEL,
                tokenCredentialId: env.SLACKCREDENTIALS,
                color: 'danger',
                message: "Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]' has failed. Check console output at ${env.BUILD_URL}."
            )
        }
        success {
            slackSend(
                channel: env.SLACKCHANNEL,
                tokenCredentialId: env.SLACKCREDENTIALS,
                color: 'good',
                message: "Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]' completed successfully. Check console output at ${env.BUILD_URL}."
            )
        }
    }
}