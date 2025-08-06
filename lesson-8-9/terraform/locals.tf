data "aws_caller_identity" "current" {}

locals {
  #S3 bucket and MongoDB
  bucket_name     = "tf-lesson9-bucket"
  table_name      = "tf-locks"

  region          = "eu-central-1"
  #VPC
  vpc_name        = "lesson-9"
  vpc_cidr_block  = "10.0.0.0/16"
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnets = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
  azs             = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
  
  #ECR
  ecr_name        = "lesson-9-chart"

  #EKS
  cluster_name = "eks-cluster-demo"
  instance_type = "t3.medium"
  desired_size = 2
  max_size = 3
  min_size = 1

  ecr_repo_url = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${local.region}.amazonaws.com/${local.ecr_name}"

  #Grafana
  grafana_release_name        = "monitoring"
  grafana_namespace           = "monitoring"
}

