variable "bucket" {
  type        = string
  description = "Name of the bucket, which must be globally unique within the AWS partition."

}

variable "region" {
  type        = string
  description = "Region of the bucket"

}

variable "status" {
  type        = string
  description = "Versioning status: Enabled or Suspended."

  validation {
    condition     = contains(["Enabled", "Suspended"], var.status)
    error_message = "status must be Enabled or Suspended."
  }

}
