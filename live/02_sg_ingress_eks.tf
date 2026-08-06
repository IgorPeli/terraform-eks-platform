module "eks_ingress_alb" {
  source = "../modules/security_group_ingress_rule"

  security_group_id = module.sg_eks.sg_id
  description       = "HTTPS from the ALB"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  source_type       = "security_group"
  source_value      = module.sg_alb.sg_id
}
