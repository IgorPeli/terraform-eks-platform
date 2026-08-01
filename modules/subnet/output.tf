output "subnet_id" {
  value       = aws_subnet.subnet.id
  description = "ID of the subnet"

}

output "route_table_id" {
  value = aws_route_table.rt.id

}