variable "release_name" {
  type    = string
  default = "kube-prometheus-stack"
}

variable "namespace" {
  type    = string
  default = "monitoring"
}

variable "chart_version" {
  type    = string
  default = "75.10.0"
}

variable "repository" {
  description = "Prometeus repository"
  type        = string
  default = "https://prometheus-community.github.io/helm-charts"
}
