resource "aws_lb_listener" "front_end" {
  load_balancer_arn = var.load_balancer_arn
  port              = var.port
  protocol          = var.protocol
  ssl_policy        = (var.protocol == "HTTPS" && var.port == "443") ? "ELBSecurityPolicy-2016-08" : null
  certificate_arn   = (var.protocol == "HTTPS" && var.port == "443") ? var.certificate_arn : null

  default_action {
    type             = "forward"
    target_group_arn = var.target_group_arn
  }
}