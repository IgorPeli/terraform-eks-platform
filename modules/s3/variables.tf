variable "bucket" {
  type        = string
  description = "Name of the bucket, must be unique per region"

}

variable "region" {
  type        = string
  description = "Region of the bucket"

}

variable "status" {
  type        = string
  description = "Enabled or Disabled"

}