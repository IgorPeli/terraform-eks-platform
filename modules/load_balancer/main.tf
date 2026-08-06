resource "aws_lb" "test" {
  name               = var.name
  internal           = var.internal
  load_balancer_type = var.load_balancer_type
  security_groups    = var.security_group_ids
  subnets            = var.subnets_ids
  access_logs {
    bucket  = var.bucket
    enabled = var.enabled
  }

  tags = merge(
    var.tags,
    {
      ManagedBy = "Terraform"
    }
  )
}