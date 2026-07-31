resource "aws_vpc_security_group_ingress_rule" "allow_tpc" {
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  security_group_id            = var.security_group_id
  referenced_security_group_id = var.referenced_security_group_id
}
