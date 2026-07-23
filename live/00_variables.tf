variable "environment_tags" {
  type        = map(string)
  description = "Tags specific to the environment."
  default     = {}
}