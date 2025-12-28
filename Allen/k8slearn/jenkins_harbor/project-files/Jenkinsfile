// Jenkins Pipeline for go-zero microservices
// 代码仓库: https://github.com/tutengdihuang/service_test.git
// 镜像仓库: Harbor (182.42.82.135:30002)

pipeline {
    agent any
    
    triggers {
        githubPush()
    }
    
    environment {
        // Harbor 配置
        HARBOR_URL = '182.42.82.135:30002'
        HARBOR_PROJECT = 'service-test'
        HARBOR_CREDENTIALS = 'harbor-credentials'
        
        // K8s 配置
        K8S_NAMESPACE = 'service-test'
        KUBECONFIG = '/var/jenkins_home/.kube/config'
    }
    
    stages {
        stage('Checkout') {
            steps {
                echo "=== 拉取代码 ==="
                checkout scm
                sh 'git log -1 --oneline'
                sh 'ls -la'
            }
        }
        
        stage('Build & Push Images') {
            steps {
                script {
                    def services = [
                        [name: 'user', dockerfile: 'dockerfiles/Dockerfile.user'],
                        [name: 'product', dockerfile: 'dockerfiles/Dockerfile.product'],
                        [name: 'trade', dockerfile: 'dockerfiles/Dockerfile.trade'],
                        [name: 'web', dockerfile: 'dockerfiles/Dockerfile.web']
                    ]
                    
                    // 登录 Harbor
                    withCredentials([usernamePassword(
                        credentialsId: env.HARBOR_CREDENTIALS,
                        usernameVariable: 'HARBOR_USER',
                        passwordVariable: 'HARBOR_PASS'
                    )]) {
                        sh "docker login -u ${HARBOR_USER} -p ${HARBOR_PASS} ${HARBOR_URL}"
                    }
                    
                    // 构建每个服务
                    services.each { svc ->
                        def imageName = "${HARBOR_URL}/${HARBOR_PROJECT}/${svc.name}-service"
                        def imageTag = "${env.BUILD_NUMBER}"
                        
                        echo "=== 构建 ${svc.name} 服务 ==="
                        
                        sh """
                            docker build \
                                -f ${svc.dockerfile} \
                                -t ${imageName}:${imageTag} \
                                -t ${imageName}:latest \
                                .
                        """
                        
                        echo "=== 推送 ${svc.name} 镜像到 Harbor ==="
                        sh """
                            docker push ${imageName}:${imageTag}
                            docker push ${imageName}:latest
                        """
                        
                        // 清理本地镜像
                        sh "docker rmi ${imageName}:${imageTag} || true"
                    }
                }
            }
        }
        
        stage('Deploy to K8s') {
            steps {
                script {
                    // 服务名和容器名映射
                    def services = [
                        [name: 'user', container: 'user'],
                        [name: 'product', container: 'product'],
                        [name: 'trade', container: 'trade'],
                        [name: 'web', container: 'web-service']
                    ]
                    
                    services.each { svc ->
                        def imageName = "${HARBOR_URL}/${HARBOR_PROJECT}/${svc.name}-service"
                        def imageTag = "${env.BUILD_NUMBER}"
                        
                        echo "=== 部署 ${svc.name} 服务 ==="
                        
                        sh """
                            kubectl set image deployment/${svc.name}-service \
                                ${svc.container}=${imageName}:${imageTag} \
                                -n ${K8S_NAMESPACE} || echo "Deployment ${svc.name}-service not found"
                        """
                    }
                }
            }
        }
        
        stage('Verify') {
            steps {
                echo "=== 验证部署状态 ==="
                sh "kubectl get pods -n ${K8S_NAMESPACE}"
            }
        }
    }
    
    post {
        success {
            echo '=== Pipeline 执行成功 ==='
        }
        failure {
            echo '=== Pipeline 执行失败 ==='
        }
        always {
            sh "docker logout ${HARBOR_URL} || true"
        }
    }
}
