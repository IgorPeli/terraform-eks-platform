variable "name" {
  type        = string
  description = "Name of the SG"

}

variable "description" {
  type        = string
  description = "Description of the SG"

}

variable "vpc_id" {
  type = string

}

variable "tags" {
  type        = map(string)
  description = "Tags"
}
