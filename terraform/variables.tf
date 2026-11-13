variable "region" {
  type    = string
  default = "ap-southeast-2"
}

variable "environment" {
  description = "staging or prod"
  type        = string
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "app_image" {
  description = "Container image to run, e.g. ghcr.io/OWNER/REPO:1.0.1"
  type        = string
}

variable "log_retention_days" {
  type    = number
  default = 14
}


