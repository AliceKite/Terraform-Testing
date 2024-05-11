terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.37.0"
    }
  }
}

resource "aws_instance" "windows" {
  count = 0
  ami = "ami-0f9c44e98edf38a2b"
  instance_type = "g4dn.xlarge"
  associate_public_ip_address = true
  key_name = "terraform-key"
  subnet_id = aws_subnet.private_subnets[0].id
  vpc_security_group_ids = [aws_security_group.allow_web.id]
  tags = {
    Name = "Your Game Goes Here"
  }
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support = true
  tags = {
    Name = "Project VPC"
  }
}

resource "aws_subnet" "public_subnets" {
  count = length(var.public_subnet_cidrs)
  vpc_id = aws_vpc.main.id
  cidr_block = element(var.public_subnet_cidrs, count.index)
  availability_zone = element(var.azs, count.index)
  map_public_ip_on_launch = true
  tags = {
    Name = "Public Subnet ${count.index + 1}"
  }
}

resource "aws_subnet" "private_subnets" {
  count = length(var.private_subnet_cidrs)
  vpc_id = aws_vpc.main.id
  cidr_block = element(var.private_subnet_cidrs, count.index)
  availability_zone = element(var.azs, count.index)
  tags = {
    Name = "Private Subnet ${count.index + 1}"
  }
}
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "Project VPC IG"
  }
}

resource "aws_route_table" "second_rt" {
  vpc_id = aws_vpc.main.id
  route{
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  tags = {
    Name = "2nd Route Table"
  }
}

resource "aws_route_table_association" "public_subnet_asso" {
  count = length(var.public_subnet_cidrs)
  subnet_id = element(aws_subnet.public_subnets[*].id, count.index)
  route_table_id = element(aws_route_table.second_rt.*.id, count.index)
}

resource "aws_eip" "nat_gateway_eip"{
  domain = "vpc"
  tags = {
    name = "gateway_eip"
  }
}

resource "aws_nat_gateway" "nat_gateway"{
  subnet_id = aws_subnet.public_subnets[0].id
  allocation_id = aws_eip.nat_gateway_eip.id
  depends_on = [aws_internet_gateway.gw]
  tags = {
    name = "nat gateway"
  }
}

resource "aws_route_table" "nat_gateway_rt" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

resource "aws_route_table_association" "nat_gateway_rt_association"{
  subnet_id = aws_subnet.private_subnets[0].id
  route_table_id = aws_route_table.nat_gateway_rt.id
}

resource "aws_security_group" "allow_web"{
  name = "allow_web_traffic"
  description = "allow web inbound traffic"
  vpc_id = aws_vpc.main.id
  ingress {
    from_port = 3389
    to_port = 3389
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress{
    from_port = 0
    to_port = 0
    protocol = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    name = "allow_web"
  }
}