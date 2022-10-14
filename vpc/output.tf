output "public_sg" {
  value = aws_security_group.test_sg["public_sg"].id
}

output "public_subnets" {
  value = aws_subnet.test_public_subnet[*].id
}

output "vpc_id" {
  value = aws_vpc.test_vpc.id
}
