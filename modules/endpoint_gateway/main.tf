resource "aws_vpc_endpoint" "gateway_endpoint" {
  vpc_id            = var.vpc_id
  service_name      = var.service_name
  service_region    = var.region
  vpc_endpoint_type = "Gateway"
  route_table_ids   = var.route_tables_ids


  tags = merge(
    var.tags, {
      Service   = "network"
      ManagedBy = "Terraform"
    }
  )
}