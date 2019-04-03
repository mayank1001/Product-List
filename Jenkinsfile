githubUserId = 'mayank1001'
forkedRepositorySshUrl = "git@github.com:${githubUserId}/Product-List.git"
forkedRepositoryName = "${githubUserId}/Product-List"
cfApiEndpoint = 'https://api.cf.sap.hana.ondemand.com'
cfOrganization = 'SAPNACFDEMO'
cfIntegrationSpace = "integration"
cfAcceptanceSpace = "acceptance"
cfProductionSpace = "production"
cfDomain = 'cfapps.sap.hana.ondemand.com'

stage('Commit'){
    cleanNode {
        git url: forkedRepositorySshUrl
	automaticVersioning()
        try {
            
            echo 'Trigger maven build'
            sh 'mvn -B clean verify'
            
        } finally {
            junit allowEmptyResults: true, testResults:'target/surefire-reports/*.xml'
            junit allowEmptyResults: true, testResults:'target/failsafe-reports/*.xml'
	    findbugs canComputeNew: false, defaultEncoding: '', excludePattern: '', healthy: '', includePattern: '', pattern: '**/findbugsXml.xml', unHealthy: ''
            pmd canComputeNew: false, defaultEncoding: '', healthy: '', pattern: '', unHealthy: ''
            jacoco()
	}
	stash includes: 'target/product-list.zip', name: 'ARTIFACTS'
    }
}

stage('Integration') {
    cleanNode {
        unstash 'ARTIFACTS'
        sh 'unzip -o "target/product-list.zip" -d "."'
        pushApplication(cfIntegrationSpace)
    }
    cleanNode {
        git url: forkedRepositorySshUrl
        try {
            sh "mvn -B clean verify -DAD_ROUTE=https://product-list-${cfIntegrationSpace}.${cfDomain}"
        } finally {
            junit allowEmptyResults: true, testResults: 'target/surefire-reports/*.xml'
            emailext body: """If this artifact should be tested, please go to the pipeline
            <a href=\'${env.BUILD_URL}/input\'>${env.JOB_NAME} [${env.BUILD_NUMBER}]</a>
            to start the deployment.""", subject: 'New version of microservice Product-List available', to: 'mayank.sharma05@sap.com'
        }
    }
        input 'Should new version be tested in acceptance?'
}

stage ('Acceptance') {
    cleanNode {
        unstash 'ARTIFACTS'
        sh 'unzip -o "target/product-list.zip" -d "."'
        pushApplication(cfAcceptanceSpace)
	emailext body: """Link to the microservice: <a href="https://product-list-${cfAcceptanceSpace}.${cfDomain}"> https://product-list-${cfIntegrationSpace}.${cfDomain}</a></br></br>
        After successful test, please go to the pipeline
	<a href=\'${env.BUILD_URL}input\'>${env.JOB_NAME} [${env.BUILD_NUMBER}]</a>
	to start the promote build.""", subject: 'Please test a new version of microservice product-list', to: 'mayank.sharma05@sap.com'
    }
    input 'Should version be accepted ?'
}

stage('Production') {
    cleanNode {
        unstash 'ARTIFACTS'
        sh 'unzip -o "target/product-list.zip" -d "."'
        pushApplication(cfProductionSpace)
	emailext body: """Link to the microservice: <a href="https://product-list-${cfProductionSpace}.${cfDomain}"> https://product-list-${cfIntegrationSpace}.${cfDomain}</a></br></br>
        New version of microservice product-list available in Production""", subject: 'New version of microservice product-list promoted to Production', to: 'mayank.sharma05@sap.com'

    }
}

def pushApplication(spaceName) {
	withCredentials([
		usernamePassword(
			credentialsId:    'CF_CREDENTIAL', 
			passwordVariable: 'CF_PASSWORD', 
			usernameVariable: 'CF_USERNAME'
		)
	]) {
        sh """
        cf login -u \${CF_USERNAME} -p \${CF_PASSWORD} -a ${cfApiEndpoint} -o ${cfOrganization} -s ${spaceName}
        //cf push -n product-list-${spaceName}
	ruby scripts/simple_blue_green.rb ${cfOrganization} ${spaceName} ${cfApiEndpoint} \${CF_USERNAME} \${CF_PASSWORD}
        """
    }
}

def cleanNode(block) {
    node {
        deleteDir()
        block()
    }
}

def executeShell(command) {
  def result = sh returnStdout: true, script: command
  return result.trim()
}

def automaticVersioning() {
  def baseVersion = executeShell 'mvn -q -Dexec.executable=\'echo\' -Dexec.args=\'${project.version}\' --non-recursive org.codehaus.mojo:exec-maven-plugin:1.3.1:exec'
  def timestamp = executeShell 'date +"%Y%m%d-%H%M%S"'
  def gitRevision = executeShell 'git rev-parse HEAD'
  version = "${baseVersion}-${timestamp}_${gitRevision}"
  sh "mvn -B versions:set -DnewVersion=${version}"

  // Push version and tag to GitHub
  buildTag = "BUILD_${version}"
  sh """
    git add pom.xml
    git commit -m 'update version'
    git tag '${buildTag}'
    git push origin '${buildTag}'
  """
}
