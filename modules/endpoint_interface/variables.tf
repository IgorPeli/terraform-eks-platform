variable "vpc_id" {
  type        = string
  description = "VPC that's the Interface Endpoint is associated."

}

variable "service_name" {
  type        = string
  description = "Type of the service that we want to associated."

}

variable "security_group_ids" {
  type        = list(string)
  description = "Security Group where we vinculate de ENI"
}

variable "tags" {
  type        = map(string)
  description = "Tags for the resource"
}

variable "subnet_ids" {
  type        = list(string)
  description = "Which subnet will have the Endpoint Interface (ENI)"

}