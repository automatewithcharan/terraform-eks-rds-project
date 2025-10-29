resource "aws_vpc" "main" {
cidr_block = "10.0.0.0/16"
enable_dns_support = true
enable_dns_hostnames = true
tags = {
  Name = "devops-vpc"
}
}

resource "aws_subnet" "public_subnet_1" {
vpc_id = aws_vpc.main.id
cidr_block = "10.0.1.0/24"
availability_zone = "ap-south-2a"
map_public_ip_on_launch = true

tags = {
  Name = "public-subnet-1"
  Tier = "public"
}
}

resource "aws_subnet" "public_subnet_2" {
vpc_id = aws_vpc.main.id
cidr_block = "10.0.2.0/24"
availability_zone = "ap-south-2b"
map_public_ip_on_launch = true
tags = {
  Name = "public-subnet-2" 
  Tier = "public" 
}
}

resource "aws_subnet" "private_subnet_1" {
vpc_id = aws_vpc.main.id
cidr_block = "10.0.3.0/24"
availability_zone = "ap-south-2a"
tags= {
  Name = "private-subnet-1"
  Tier = "private"
}
}

resource "aws_subnet" "private_subnet_2" {
vpc_id = aws_vpc.main.id
cidr_block = "10.0.4.0/24"
availability_zone = "ap-south-2b" 
tags = {
  Name = "private-subnet-2"
  Tier = "private"
}
}

resource "aws_internet_gateway" "igw" {
vpc_id = aws_vpc.main.id
tags = {
  Name = "devops-igw"
}
}

resource "aws_route_table" "public_rt" {
vpc_id = aws_vpc.main.id

route {
  cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.igw.id
}
tags = {
  Name = "public-route-table"
}
}

resource "aws_route_table_association" "public_subnet_1_assoc" {
subnet_id = aws_subnet.public_subnet_1.id
route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_subnet_2_assoc" {
subnet_id = aws_subnet.public_subnet_2.id
route_table_id = aws_route_table.public_rt.id
}

# Elastic IP for NAT Gateway
resource "aws_eip" "nat_eip" {
  domain = "vpc"

  tags = {
    Name = "nat-eip"
  }
}

# NAT Gateway (in a Public Subnet)
resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet_1.id

  tags = {
    Name = "nat-gateway"
  }

  depends_on = [aws_internet_gateway.igw]
}

# Private Route Table
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }

  tags = {
    Name = "private-route-table"
  }
}

# Associate Private Subnets with Route Table
resource "aws_route_table_association" "private_subnet_1_assoc" {
  subnet_id      = aws_subnet.private_subnet_1.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "private_subnet_2_assoc" {
  subnet_id      = aws_subnet.private_subnet_2.id
  route_table_id = aws_route_table.private_rt.id
}

