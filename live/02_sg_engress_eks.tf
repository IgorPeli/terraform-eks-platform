module "sg_egress_eks_ecr" {
  name        = "egress-eks-ecr"
  description = "SG that allow egress to Interface Endpoint ECR"
  source      = "../modules/security_group_egress"
  vpc_id      = module.vpc.vpc_id
  tags = merge(
    var.environment_tags,
    {
      Owner = "Ig0d"
      Type  = "Egress"

  })
}

module "sg_egress_eks_ecr_rule" {
  source                       = "../modules/security_group_egress_rule.tf"
  referenced_security_group_id = module.sg_ingress_interface.sg_id
  security_group_id            = module.sg_egress_eks_ecr.sg_id
}
