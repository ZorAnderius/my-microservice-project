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
  source = "./modules/eks"
  cluster_name = local.cluster_name
  subnet_ids = module.vpc.public_subnet_ids
  instance_type = local.instance_type
  desired_size = local.desired_size
  max_size = local.max_size
  min_size = local.min_size
}
