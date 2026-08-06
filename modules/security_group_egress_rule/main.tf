resource "aws_vpc_security_group_egress_rule" "rule" {
  security_group_id = var.security_group_id
  description       = var.description
  ip_protocol       = var.ip_protocol
  from_port         = var.from_port
  to_port           = var.to_port

  cidr_ipv4 = (
    var.destination_type == "cidr_ipv4" ? var.destination : null
  )

  prefix_list_id = (
    var.destination_type == "prefix_list" ? var.destination : null
  )

  referenced_security_group_id = (var.destination_type == "security_group" ? var.destination : null
  )
}
