resource "aws_vpc_security_group_egress_rule" "allow_udp_dns" {
  security_group_id = var.security_group_id
  ip_protocol       = "udp"
  cidr_ipv4         = "10.16.0.2/32"
  from_port         = 53
  to_port           = 53
}

resource "aws_vpc_security_group_egress_rule" "allow_tcp_https" {
  security_group_id            = var.security_group_id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  referenced_security_group_id = var.referenced_security_group_id
}
