output "vpc_id" {
  value = module.vpc.vpc_id
}

output "ecr_url" {
  value = module.ecr.ecr_url
}

output "eks_cluster_name" {
  value = module.eks.eks_cluster_name
}

output "ecr_repo_name" {
  value = module.ecr.repo_name
}

output "aws_region" {
  value = local.region
}