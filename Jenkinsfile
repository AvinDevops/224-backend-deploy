pipeline {
    agent {
        label 'AGENT-1'
    }
    options {
        timeout(time: 30, unit: 'MINUTES')
        disableConcurrentBuilds()
        ansiColor('Xterm')
    }
    parameters {
        string(name: 'appVersion', defaultValue: '1.0.0', description: 'give application version!')
    }
    environment {
        def appVersion = ''
    }
    stages {
        stage ('Test') {
            steps {
               script {
                echo "Application version is: ${params.appVersion}"
               }
            }
        }
    }
    post {
        always {
            echo 'I will run pipeline always, success or failure'
            deleteDir()
        }
        success {
            echo 'I will run when pipeline is success'
        }
        failure {
            echo 'I will run when pipeline is failure'
        }
    }
}