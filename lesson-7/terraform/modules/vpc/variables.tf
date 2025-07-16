variable "vpc_cidr_block" {
  type = string
  description = "CIDR block for VPC"
}

variable "vpc_name" {
  type = string
  description = "VPC name"
}

variable "public_subnets" {
  type = list(string)
  description = "List of CIDR blocks for public subnets"
}

variable "private_subnets" {
  type = list(string)
  description = "List of CIDR blocks for private subnets"
}

variable "availability_zones" {
  type = list(string)
  description = "List of availability zones"
}