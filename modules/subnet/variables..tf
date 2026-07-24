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
  type        = list(string)
  description = "AZs from the subnet"

}