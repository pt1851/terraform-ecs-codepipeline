
variable "stages" {
    description = "List of maps of codebuild stages"
}

variable "environment" {
  description = "environment name"
}

variable "image_name" {
    description = "Desired image name"
}

variable "sg_id" {
    description = "codebuild security group id"
}

variable "build_spec_path" {}

variable "source_branch_name" {}

variable "vpc_id" {}

variable "subnet_id" {}

variable "region" {}

variable "repo_id" {}
