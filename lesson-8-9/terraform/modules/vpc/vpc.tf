#create VPC
resource "aws_vpc" "tf_vpc" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.vpc_name}-vpc"
  }
}

#config public subnet
resource "aws_subnet" "public" {
  count                   = length(var.public_subnets)
  vpc_id                  = aws_vpc.tf_vpc.id
  cidr_block              = var.public_subnets[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.vpc_name}-public-${count.index + 1}"
  }
}

#config private subnet
resource "aws_subnet" "private" {
  count             = length(var.private_subnets)
  vpc_id            = aws_vpc.tf_vpc.id
  cidr_block        = var.private_subnets[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name                        = "${var.vpc_name}-private-${count.index + 1}"
    "kubernetes.io/cluster/dev" = "shared"
  }
}

#create Internet  Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.tf_vpc.id

  tags = {
    Name = "${var.vpc_name}-igw"
  }
}


# #create NAT gateway
# resource "aws_eip" "nat_gateway" {
#   count = length(var.public_subnets)
#   domain = "vpc"

#   tags = {
#     Name = "${var.vpc_name}-nat-eip-${count.index  + 1}"
#   }
# }

# resource "aws_nat_gateway" "nat_gateway" {
#   count = length(var.public_subnets)
#   allocation_id = aws_eip.nat_gateway[count.index].id
#   subnet_id = aws_subnet.public[count.index].id

#   tags = {
#     Name = "${var.vpc_name}-nat-gateway-${count.index + 1}"
#   }

#   depends_on = [ aws_internet_gateway.igw ]
# }
