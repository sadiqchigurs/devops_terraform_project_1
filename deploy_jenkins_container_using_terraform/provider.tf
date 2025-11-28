terraform {
  
  required_providers {
    aws = {
        source = "hashicorp/aws"
        version = "~> 5.0"
    }

  }

  backend "s3" {
    bucket = "devopslearningcircle-terraform-statefile"
    key = "deploy_jenkins_container/terraform.tfstate"
    # use_lockfile = true # Ensures consistent provider versions
    encrypt = false
    region = "us-east-1"
  }

}

provider "aws" {
  region = "us-east-1"
}