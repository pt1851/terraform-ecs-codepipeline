
variable "stages" {
    description = "List of maps of codebuild stages"
}

variable "environment" {
  description = "environment name"
}

variable "image_name" {
    description = "Desired image name"
}

variable "build_spec_path" {}

variable "source_branch_name" {}

variable "vpc_id" {}

variable "subnet_id" {}

variable "region" {}

variable "repo_id" {}

variable "common_name" {}

variable "codebuild_build_timeout" {}
variable "codebuild_bucket" {
  
}
variable "codepipeline_bucket" {
  
}