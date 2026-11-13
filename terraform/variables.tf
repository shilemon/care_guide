variable "region" {
  type    = string
  default = "us-east-1"
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

variable "ami_id" {
  description = "Leave empty to use the latest Amazon Linux 2023 AMI"
  type        = string
  default     = ""
}

variable "use_localstack" {
  description = "true = talk to LocalStack on localhost:4566 instead of real AWS"
  type        = bool
  default     = false
}
