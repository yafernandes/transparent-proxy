variable "project_name" {
  default = "transparent-proxy"
}

variable "aws_credential_file" {}

variable "ssh_public_key_file" {}

variable "region" {}

variable "domain" {}

variable "creator" {}

variable "instance_type" {
  default = "t3a.small"
}
