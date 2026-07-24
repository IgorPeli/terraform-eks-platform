variable "vpc_id" {
  type        = string
  description = "VPC em que a VPC vai ser inserida"

}

variable "cidr_block" {
  type        = string
  description = "CIDR for the Subnet, use / in the end for the mask."

}

variable "tags" {
  type        = map(string)
  description = "tag for the resource."
}

variable "availability_zone" {
  type        = string
  description = "AZs from the subnet"

}

variable "is_public" {
  type        = bool
  description = "If the subnet it's public"
  default     = false

}

variable "gateway_id" {
  type        = string
  description = "ID from my Internet Gateway"
  default     = ""

}