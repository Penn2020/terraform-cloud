
locals {
  public-subnet-name = "cali-subnet1"
  private-subnet-name = "cali-subnet2"
  availability_zone = ["us-east-1a", "us-east-1b"]
}

# VPC for the cali eks cluster
resource "aws_vpc" "cali-vpc" {
  cidr_block       = var.vpc_cidr
  instance_tenancy = "default"
  enable_dns_hostnames = true
  enable_dns_support = true

  tags = {
    Name = var.vpc-name
    "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared"
  }
}

resource "aws_internet_gateway" "cali-igw" {
  vpc_id = aws_vpc.cali-vpc.id

  tags = {
    Name = var.igw-name
  }
}

#public subnet for cali-eks cluster
resource "aws_subnet" "cali-pub-subnet" {
  count      = length(var.pub_cidr_block)
  vpc_id     = aws_vpc.cali-vpc.id
  cidr_block = element(var.pub_cidr_block,count.index)
  availability_zone = element(local.availability_zone,count.index)

  tags = {
    Name = local.public-subnet-name
    "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared"
    "kubernetes.io/role/elb" = 1
  }
}

#private subnet for cali-eks cluster
resource "aws_subnet" "cali-priv-subnet" {
  count      = length(var.private_cidr_block)
  vpc_id     = aws_vpc.cali-vpc.id
  cidr_block = element(var.private_cidr_block,count.index)
  availability_zone = element(local.availability_zone,count.index)
  
  tags = {
    Name = local.private-subnet-name
    "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb" = 1
  }
}


resource "aws_nat_gateway" "myngw" {
  subnet_id     = aws_subnet.cali-pub-subnet[0].id

  tags = {
    Name = "cali gw NAT"
  }

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.cali-igw]
}


resource "aws_route_table" "cali-pub-rt" {
  vpc_id = aws_vpc.cali-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.cali-igw.id
  }

  # route {
  #   ipv6_cidr_block        = "::/0"
  #   egress_only_gateway_id = aws_egress_only_internet_gateway.example.id
  # }

  tags = {
    Name = "cali-pub-rt"
  }
}

########## pub rt association ########################################
resource "aws_route_table_association" "cali_asso-rt-pub" {
  subnet_id      = aws_subnet.cali-pub-subnet
  route_table_id = aws_route_table.cali-pub-rt.id
}

#### private subnet configuration #######################################
resource "aws_route_table" "cali-private-subnet" {
  vpc_id =aws_vpc.cali-vpc.id
  

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.myngw.id
  }

  tags = {
    Name = "cali-priv-subnet"
  }
}