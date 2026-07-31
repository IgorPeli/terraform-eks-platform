resource "aws_vpc_endpoint" "interface" {
  vpc_id              = var.vpc_id
  vpc_endpoint_type   = "Interface"
  service_name        = var.service_name
  security_group_ids  = var.security_group_ids
  private_dns_enabled = true
  tags = merge(
    var.tags,
    {
      Service   = "network"
      ManagedBy = "Terraform"
  })
  subnet_ids = var.subnet_ids
}