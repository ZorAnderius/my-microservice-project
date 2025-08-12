#PUBLIC ROUTES

#create route's table for public subnets
resource "aws_route_table" "routes" {
  vpc_id = aws_vpc.tf_vpc.id

  tags = {
    Name = "${var.vpc_name}-public_route"
  }
}

#route to access the internet via Internet Gateway 
resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.routes.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

#bind the route table to public subnets
resource "aws_route_table_association" "routes" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.routes.id
}


# #PRIVATE ROUTES

# #create route's table for private subnets
# resource "aws_route_table" "private" {
#   count  = length(var.private_subnets)
#   vpc_id = aws_vpc.tf_vpc.id

#   tags = {
#     Name = "${var.vpc_name}-private-rt-${count.index + 1}"
#   }
# }

# #route to NAT gateway for private subnets
# resource "aws_route" "private" {
#   count                  = length(aws_route_table.private)
#   route_table_id         = aws_route_table.private[count.index].id
#   destination_cidr_block = "0.0.0.0/0"
#   nat_gateway_id         = aws_nat_gateway.nat_gateway[count.index % length(aws_nat_gateway.nat_gateway)].id
# }

# #bind the route table to public subnets
# resource "aws_route_table_association" "private" {
#   count          = length(var.private_subnets)
#   subnet_id      = aws_subnet.private[count.index].id
#   route_table_id = aws_route_table.private[count.index].id
# }
