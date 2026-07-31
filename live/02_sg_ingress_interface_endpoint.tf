module "sg_ingress_interface" {
  name        = "ingress-eks-ecr"
  description = "SG thats allow ingress from EKS"
  source      = "../modules/security_group_ingress"
  vpc_id      = module.vpc.vpc_id
  tags = merge(
    var.environment_tags,
    {
      Owner = "Ig0d"
      Type  = "Ingress"
    }
  )
}

module "sg_ingress_interface_rule" {
  source                       = "../modules/security_group_ingress_rule.tf"
  referenced_security_group_id = module.sg_egress_eks_ecr.sg_id
  security_group_id            = module.sg_ingress_interface.sg_id
}
