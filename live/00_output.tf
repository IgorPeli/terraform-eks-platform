output "igw_id" {
  value       = resource.aws_internet_gateway.internet_gateway.id
  description = "ID from the IGW"

}