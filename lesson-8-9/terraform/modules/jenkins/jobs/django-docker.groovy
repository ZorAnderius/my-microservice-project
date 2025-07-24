pipelineJob("django-app") {
  definition {
    cpsScm {
      scriptPath("lesson-8-9/terraform/Jenkinsfile")
      scm {
        git {
          remote {
            url("${repo_url}")            // підставиться з environmentVariables Jenkins
            credentials("github-token")
          }
          branches("*/${branch}")          // також підставиться
        }
      }
    }
  }
}
