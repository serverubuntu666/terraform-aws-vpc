data "aws_availability_zones" "azs" {}

resource "random_shuffle" "az_list" {
  input        = data.aws_availability_zones.azs.names
  result_count = var.max_subnets
}

resource "random_integer" "int" {
  min = 1
  max = 100

}
resource "aws_vpc" "test_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "test_vpc-${random_integer.int.id}"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_subnet" "test_public_subnet" {
  count                   = var.public_subnet_count
  vpc_id                  = aws_vpc.test_vpc.id
  cidr_block              = var.public_cidrs[count.index]
  map_public_ip_on_launch = true
  availability_zone       = random_shuffle.az_list.result[count.index]

  tags = {
    Name = "test_public_subnet-${count.index + 1}"
  }
}

resource "aws_subnet" "test_private_subnet" {
  count             = var.private_subnet_count
  vpc_id            = aws_vpc.test_vpc.id
  cidr_block        = var.private_cidrs[count.index]
  availability_zone = random_shuffle.az_list.result[count.index]

  tags = {
    Name = "test_private_subnet-${count.index + 1}"
  }

}

resource "aws_internet_gateway" "test_igw" {
  vpc_id = aws_vpc.test_vpc.id

  tags = {
    Name = "test-igw"
  }
}

resource "aws_route_table" "test_public_rt" {
  vpc_id = aws_vpc.test_vpc.id

  tags = {
    Name = "test-public-rt"
  }
}

resource "aws_route_table_association" "test_public_rt_assoc" {
  count          = var.public_subnet_count
  subnet_id      = aws_subnet.test_public_subnet[count.index].id
  route_table_id = aws_route_table.test_public_rt.id
}

resource "aws_route" "default_route" {
  route_table_id         = aws_route_table.test_public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.test_igw.id

}

resource "aws_default_route_table" "test_private_rt" {
  default_route_table_id = aws_vpc.test_vpc.default_route_table_id

  tags = {
    Name = "test-private-rt"
  }
}

resource "aws_security_group" "test_sg" {
  for_each    = var.security_group
  name        = each.value.name
  description = each.value.description
  vpc_id      = aws_vpc.test_vpc.id

  dynamic "ingress" {
    for_each = each.value.ingress
    content {
      from_port   = ingress.value.from
      to_port     = ingress.value.to
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_subnet_group" "test_rds_subnet_group" {
  count      = var.db_subnet_group == true ? 1 : 0
  name       = var.db_subnet_group_name
  subnet_ids = aws_subnet.test_private_subnet[*].id

  tags = {
    Name = var.db_subnet_group_tags
  }

}
