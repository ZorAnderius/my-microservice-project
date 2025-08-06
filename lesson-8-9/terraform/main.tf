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

module "monitoring" {
  source = "./modules/monitoring"
  depends_on = [
    module.eks
  ]
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
    helm       = helm
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
  rds_db_name     = var.rds_database_name
  rds_username    = var.rds_username
  rds_password    = var.rds_password
  rds_endpoint    = module.rds.rds_endpoint

  depends_on = [module.eks]
}

module "rds" {
  source = "./modules/rds"

  name                  = "${var.rds_database_name}-db"
  use_aurora            = var.rds_use_aurora
  aurora_instance_count = 2
  vpc_cidr_block        = local.vpc_cidr_block

  # --- Aurora-only ---
  engine_cluster                = var.rds_aurora_engine
  engine_version_cluster        = var.rds_aurora_engine_version
  parameter_group_family_aurora = var.rds_aurora_parameter_group_family


  # --- RDS-only ---
  engine                     = var.rds_instance_engine
  engine_version             = var.rds_instance_engine_version
  parameter_group_family_rds = var.rds_instance_parameter_group_family

  # Common
  instance_class          = var.rds_instance_class
  allocated_storage       = 20
  db_name                 = var.rds_database_name
  username                = var.rds_username
  password                = var.rds_password
  subnet_private_ids      = module.vpc.private_subnet_ids
  subnet_public_ids       = module.vpc.public_subnet_ids
  publicly_accessible     = var.rds_publicly_accessible
  vpc_id                  = module.vpc.vpc_id
  multi_az                = var.rds_multi_az
  backup_retention_period = var.rds_backup_retention_period
  parameters = {
    max_connections            = "200"
    log_min_duration_statement = "500"
  }

  tags = {
    Environment = "dev"
    Project     = var.rds_database_name
  }
  depends_on = [
    module.vpc
  ]
}

