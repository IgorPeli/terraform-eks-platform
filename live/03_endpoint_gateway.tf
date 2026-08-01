module "s3_gateway" {
  source           = "../modules/endpoint_gateway"
  service_name     = "com.amazonaws.us-east-2.s3"
  vpc_id           = module.vpc.vpc_id
  route_tables_ids = [module.subnet-private-b.route_table_id, module.subnet-private-a.route_table_id]
  tags = merge(
    var.environment_tags,
    {
      Purpose = "eks-interface-endpoints"
      Owner   = "Ig0d"
    }

  )
}