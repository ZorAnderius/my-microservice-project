variable "github_user" {
  type        = string
  description = "GitHub username"
}

variable "github_token" {
  type        = string
  description = "GitHub Access Token"
  sensitive = true
}

variable "github_repo_url" {
  type        = string
  description = "GitHub repository name"
}

variable "github_branch" {
  type        = string
  description = "GitHub branch name"
}