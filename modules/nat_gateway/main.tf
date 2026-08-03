resource "aws_nat_gateway" "nat_gateway" {
  availability_mode = "regional"
  connectivity_type = "public"
  vpc_id            = var.vpc_id
  tags = merge(
    var.tags,
    { Purpose   = "eks-interface-endpoints"
      ManagedBy = "Terraform"
  })
}
