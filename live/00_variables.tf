variable "environment_tags" {
  type        = map(string)
  description = "Tags specific to the environment."
  default     = {}

}

variable "environment" {
  type        = string
  description = "Deployment environment"
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging or prod."
  }
}