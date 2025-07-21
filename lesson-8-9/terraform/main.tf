terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.0.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0.0"
    }
  }
}

provider "aws" {
  region = local.region
}

module "vpc" {
  source             = "./modules/vpc"
  vpc_cidr_block     = local.vpc_cidr_block
  public_subnets     = local.public_subnets
  private_subnets    = local.private_subnets
  availability_zones = local.azs
  vpc_name           = local.vpc_name
}

module "ecr" {
  source       = "./modules/ecr"
  ecr_name     = local.ecr_name
  scan_on_push = true
}

module "eks" {
  source        = "./modules/eks"
  cluster_name  = local.cluster_name
  subnet_ids    = module.vpc.public_subnet_ids
  instance_type = local.instance_type
  desired_size  = local.desired_size
  max_size      = local.max_size
  min_size      = local.min_size
}


data "aws_eks_cluster" "eks" {
  name       = module.eks.eks_cluster_name
  depends_on = [module.eks]
}

data "aws_eks_cluster_auth" "eks" {
  name       = module.eks.eks_cluster_name
  depends_on = [module.eks]
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.eks.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.eks.token
}

provider "helm" {
  kubernetes = {
    host                   = data.aws_eks_cluster.eks.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.eks.token
  }
}


module "jenkins" {
  source            = "./modules/jenkins"
  cluster_name      = module.eks.eks_cluster_name
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url
  github_token      = var.github_token
  github_user       = var.github_user
  github_repo_url   = var.github_repo_url
  github_branch     = var.github_branch

  depends_on = [module.eks]
  providers = {
    kubernetes = kubernetes
  }
}

module "argo_cd" {
  source          = "./modules/argo_cd"
  namespace       = "argocd"
  chart_version   = "5.46.4"
  github_token    = var.github_token
  github_user     = var.github_user
  github_repo_url = var.github_repo_url
  github_branch   = var.github_branch
  ecr_repo_url    = local.ecr_repo_url

  depends_on = [module.eks]
}

