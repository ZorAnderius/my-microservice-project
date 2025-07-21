variable "name" {
  description = "Назва Helm-релізу"
  type        = string
  default     = "argo-cd"
}

variable "namespace" {
  description = "K8s namespace для Argo CD"
  type        = string
  default     = "argocd"
}

variable "chart_version" {
  description = "Версія Argo CD чарта"
  type        = string
  default     = "5.46.4" 
}

variable "github_repo_url" {
  type        = string
  description = "URL до GitHub репозиторію"
}

variable "github_user" {
  type        = string
  description = "GitHub username"
}

variable "github_token" {
  type        = string
  sensitive   = true
  description = "GitHub token"
}

variable "github_branch" {
  type        = string
  description = "GitHub branch name"
}

variable "ecr_repo_url" {
  type = string
}

