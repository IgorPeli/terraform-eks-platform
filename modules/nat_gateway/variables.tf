variable "vpc_id" {
  type        = string
  description = "VPC to be associated"

}

variable "tags" {
  type = map(string)

}