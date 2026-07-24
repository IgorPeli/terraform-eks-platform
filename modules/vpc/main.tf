resource "aws_vpc" "main" {
  cidr_block           = var.cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true
  region               = "us-east-2"
  tags = merge(
    {
      Service   = "network"
      ManagedBy = "Terraform"
    },
    var.tags
  )
}