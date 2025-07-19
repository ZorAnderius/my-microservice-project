output "ecr_url" {
  value = aws_ecr_repository.repository.repository_url
}

output "repo_name" {
  value = aws_ecr_repository.repository.name
}