variable "security_group_id" {
  type        = string
  description = "ID of the security group that receives the egress rule."
}

variable "description" {
  type        = string
  description = "Description of the egress rule."
  default     = null
}

variable "ip_protocol" {
  type        = string
  description = "IP protocol used by the rule."
}

variable "from_port" {
  type        = number
  description = "Start of the destination port range."
}

variable "to_port" {
  type        = number
  description = "End of the destination port range."
}

variable "destination_type" {
  type        = string
  description = "Destination type: cidr_ipv4, prefix_list or security_group."

  validation {
    condition = contains([
      "cidr_ipv4",
      "prefix_list",
      "security_group"
    ], var.destination_type)

    error_message = "destination_type must be cidr_ipv4, prefix_list or security_group."
  }
}

variable "destination" {
  type        = string
  description = "CIDR, prefix list ID or security group ID."
}
