resource "aws_lb" "test" {
  name               = var.name
  internal           = var.internal
  load_balancer_type = var.load_balancer_type
  security_groups    = var.security_group_ids
  subnets            = var.subnets_ids

  tags = merge(
    var.tags,
    {
      ManagedBy = "Terraform"
    }
  )
}