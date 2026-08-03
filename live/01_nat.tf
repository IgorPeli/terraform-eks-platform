module "nat_gateway" {
  source     = "../modules/nat_gateway"
  vpc_id     = module.vpc.vpc_id
  depends_on = [aws_internet_gateway.internet_gateway]
  tags = merge(var.environment_tags, {
    Type  = "Network"
    Owner = "Ig0d"
  })
}