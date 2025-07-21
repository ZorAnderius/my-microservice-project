variable "kubeconfig" {
  description = "Шлях до kubeconfig файлу"
  type        = string
  default     = ""
}

variable "cluster_name" {
  description = "Назва Kubernetes кластера"
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN OIDC провайдера для IRSA"
  type        = string
}

variable "oidc_provider_url" {
  description = "URL OIDC провайдера для IRSA"
  type        = string
}


variable "github_token" {
  type      = string
  sensitive = true
}

variable "github_user" {
  type = string
}

variable "github_repo_url" {
  type = string
}

variable "github_branch" {
  type = string
}
