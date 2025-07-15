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
