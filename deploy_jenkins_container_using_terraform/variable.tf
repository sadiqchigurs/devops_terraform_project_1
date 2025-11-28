variable "vpc_name" {
  type = string
  default = "deploy_jenkins_container_using_terraform"
}

variable "instance_type" {
  type = string
  default = "t2.micro"
}

variable "key_name" {
  type = string
  default = "iac_key"
}