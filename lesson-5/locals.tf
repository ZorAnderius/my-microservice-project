locals {
  bucket_name     = "tf-lesson5-bucket"
  table_name      = "tf-locks"
  region          = "eu-central-1"
  vpc_name        = "lesson-5"
  vpc_cidr_block  = "10.0.0.0/16"
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnets = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
  azs             = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
  ecr_name        = "lesson-5-ecr"
}
