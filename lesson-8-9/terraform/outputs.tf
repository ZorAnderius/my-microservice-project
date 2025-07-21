output "vpc_id" {
  value = module.vpc.vpc_id
}

output "ecr_url" {
  value = module.ecr.ecr_url
}

output "ecr_repo_name" {
  value = module.ecr.repo_name
}

output "eks_cluster_name" {
  value = module.eks.eks_cluster_name
}

output "eks_cluster_endpoint" {
  value = module.eks.eks_cluster_endpoint
}

output "eks_cluster_ca_data" {
  value = module.eks.eks_cluster_ca_data
}

output "oidc_provider_arn" {
  value = module.eks.oidc_provider_arn
}

output "oidc_provider_url" {
  value = module.eks.oidc_provider_url
}

output "jenkins_release_name" {
  value = module.jenkins.jenkins_release_name
}

output "jenkins_namespace" {
  value = module.jenkins.jenkins_namespace
}

output "aws_region" {
  value = local.region
}


output "argocd_server_service" {
  description = "ArgoCD server service"
  value       = module.argo_cd.argo_cd_server_service
}

output "argocd_admin_password" {
  description = "Initial admin password"
  value       = module.argo_cd.admin_password
}
