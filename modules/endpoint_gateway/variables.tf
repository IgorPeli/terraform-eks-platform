variable "vpc_id" {
  type        = string
  description = "VPC ID of the endpoint gateway"

}

variable "service_name" {
  type        = string
  description = "Type of service, (S3 or DDB)"

}

variable "region" {
  type    = string
  default = "us-east-2"

}

variable "route_tables_ids" {
  type        = list(string)
  description = "Subnets that will recive the prefix list to acess the S3."

}

variable "tags" {
  type        = map(string)
  description = "Tags of the resource"

}

