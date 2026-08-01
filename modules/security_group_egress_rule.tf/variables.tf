variable "referenced_security_group_id" {
  type = string
}

variable "security_group_id" {
  type = string
}

variable "prefix_list_id" {
  type        = string
  description = "Prefix list of the Gateway Endpoint"

}