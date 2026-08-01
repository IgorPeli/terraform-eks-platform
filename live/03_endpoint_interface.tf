module "ecr_interface" {
  source             = "../modules/endpoint_interface"
  vpc_id             = module.vpc.vpc_id
  security_group_ids = [module.sg_ingress_interface.sg_id]
  service_name       = "com.amazonaws.us-east-2.ecr.dkr"
  subnet_ids         = [module.subnet-private-b.subnet_id, module.subnet-private-a.subnet_id]
  tags = merge(
    var.environment_tags,
    {
      Purpose = "eks-interface-endpoints"
      Owner   = "Ig0d"
    }
  )
}

module "api_interface" {
  source             = "../modules/endpoint_interface"
  vpc_id             = module.vpc.vpc_id
  security_group_ids = [module.sg_ingress_interface.sg_id]
  service_name       = "com.amazonaws.us-east-2.ecr.api"
  subnet_ids         = [module.subnet-private-b.subnet_id, module.subnet-private-a.subnet_id]
  tags = merge(
    var.environment_tags,
    {
      Purpose = "eks-interface-endpoints"
      Owner   = "Ig0d"
    }
  )

}