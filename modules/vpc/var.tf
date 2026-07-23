variable "cidr_block" {
  type        = string
  default     = "10.16.0.0/16"
  description = "CIDR from VPC, use / in the end for the mask."

}

variable "tags" {
  type        = map(string)
  description = "tag for the resource."
}