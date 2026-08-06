resource "aws_vpc_security_group_ingress_rule" "rule" {
  security_group_id = var.security_group_id
  description       = var.description
  ip_protocol       = var.ip_protocol
  from_port         = var.from_port
  to_port           = var.to_port

  cidr_ipv4 = (
    var.source_type == "cidr_ipv4" ? var.source_value : null
  )

  prefix_list_id = (
    var.source_type == "prefix_list" ? var.source_value : null
  )

  referenced_security_group_id = (
    var.source_type == "security_group" ? var.source_value : null
  )
}
