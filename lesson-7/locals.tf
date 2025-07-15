locals {
  #S3 bucket and MongoDB
  bucket_name     = "tf-lesson5-bucket"
  table_name      = "tf-locks"

  region          = "eu-central-1"
  #VPC
  vpc_name        = "lesson-5"
  vpc_cidr_block  = "10.0.0.0/16"
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnets = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
  azs             = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
  
  #ECR
  ecr_name        = "lesson-7-chart"

  #EKS
  cluster_name = "eks-cluster-demo"
  instance_type = "t3.micro"
  desired_size = 1
  max_size = 2
  min_size = 1
}
