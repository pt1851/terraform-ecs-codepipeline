output "codebuild_name" {
  value = aws_codebuild_project.codebuild.name
}

output "codestar_arn" {
  value = aws_codestarconnections_connection.codepipeline.arn
}

output "ecr.repo_url" {
  value = aws_ecr_repository.repo.repository_url
}
