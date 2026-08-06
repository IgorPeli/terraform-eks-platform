variable "name" {
  type        = string
  description = "Name of the security group."
}

variable "description" {
  type        = string
  description = "Description of the security group."
}

variable "vpc_id" {
  type        = string
  description = "ID of the VPC where the security group will be created."
}

variable "tags" {
  type        = map(string)
  description = "Additional tags for the security group."
  default     = {}
}
