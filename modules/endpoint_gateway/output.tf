output "prefix_list_id" {
  value       = aws_vpc_endpoint.gateway_endpoint.prefix_list_id
  description = "Prefix list of associate Gateway Endpoint"

}