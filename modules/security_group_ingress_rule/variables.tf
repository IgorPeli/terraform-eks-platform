variable "security_group_id" {
  type        = string
  description = "ID of the security group that receives the ingress rule."
}

variable "description" {
  type        = string
  description = "Description of the ingress rule."
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

variable "source_type" {
  type        = string
  description = "Source type: cidr_ipv4, prefix_list or security_group."

  validation {
    condition = contains([
      "cidr_ipv4",
      "prefix_list",
      "security_group"
    ], var.source_type)

    error_message = "source_type must be cidr_ipv4, prefix_list or security_group."
  }
}

variable "source_value" {
  type        = string
  description = "CIDR, prefix list ID or security group ID."
}
