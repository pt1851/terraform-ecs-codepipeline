data "aws_caller_identity" "current" {}

data "aws_s3_bucket" "codebuild" {
  bucket = var.codebuild_bucket
}

data "aws_s3_bucket" "codepipeline" {
  bucket =var.codepipeline_bucket
}

# resource "aws_s3_bucket_acl" "codebuild" {
#   bucket = aws_s3_bucket.codebuild.id
#   acl    = "private"
# }

resource "aws_iam_role" "codebuild" {
  name = "${var.common_name}-${var.image_name}-codebuild-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codebuild.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "codebuild" {
  role = aws_iam_role.codebuild.name

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Resource": [
        "*"
      ],
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:CreateNetworkInterface",
        "ec2:DescribeDhcpOptions",
        "ec2:DescribeNetworkInterfaces",
        "ec2:DeleteNetworkInterface",
        "ec2:DescribeSubnets",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeVpcs",
        "ecr:BatchCheckLayerAvailability",
        "ecr:CompleteLayerUpload",
        "ecr:GetAuthorizationToken",
        "ecr:InitiateLayerUpload",
        "ecr:PutImage",
        "ecr:UploadLayerPart",
        "iam:PassRole",
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:CreateNetworkInterfacePermission"
      ],
      "Resource": [
        "arn:aws:ec2:${var.region}:${data.aws_caller_identity.current.account_id}:network-interface/*"
      ],
      "Condition": {
                "StringEquals": {
                    "ec2:AuthorizedService": "codebuild.amazonaws.com"
              }
            }
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:*"
      ],
      "Resource": [
        "${aws_s3_bucket.codebuild.arn}",
        "${aws_s3_bucket.codebuild.arn}/*",
        "${aws_s3_bucket.codepipeline_bucket.arn}",
        "${aws_s3_bucket.codepipeline_bucket.arn}/*"
      ]
    }
  ]
}
POLICY
}

resource "aws_codebuild_project" "codebuild" {
  name          = "${var.common_name}-${var.image_name}"
  description   = "${var.common_name}-${var.image_name}"
  build_timeout = var.codebuild_build_timeout
  service_role  = aws_iam_role.codebuild.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  # cache {
  #   type     = "S3"
  #   location = aws_s3_bucket.codebuild.bucket
  # }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:4.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true
    environment_variable {
      name  = "REPOSITORY_URI"
      value = aws_ecr_repository.repo.repository_url
    }
  }

  logs_config {
    cloudwatch_logs {
      group_name  = "${var.common_name}-${var.image_name}-codebuild"
      stream_name = "${var.common_name}-${var.image_name}"
    }

    s3_logs {
      status   = "ENABLED"
      location = "${aws_s3_bucket.codebuild.id}/${var.common_name}-codebuild/build-log"
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = var.build_spec_path
  }

  source_version = var.source_branch_name

  vpc_config {
    vpc_id = var.vpc_id

    subnets = var.subnet_id[0]

    security_group_ids = [aws_security_group.codebuild.id]
  }

  tags = {
    Environment = var.environment
  }
}

resource "aws_security_group" "codebuild" {
  name        = "${var.common_name}-${var.image_name}-codebuild-sg"
  description = "Default SG to alllow traffic from the VPC"
  vpc_id      = var.vpc_id

  egress {
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    self        = "true"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Environment = "${var.environment}"
  }
}


##################-- CodePipeline --##########################


resource "aws_codepipeline" "codepipeline" {
  name     = "${var.common_name}-${var.image_name}"
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = data.aws_s3_bucket.codepipeline_bucket.bucket
    type     = "S3"

  }

  dynamic "stage" {
    for_each = [for s in var.stages : {
      name   = s.name
      action = s.action
    } if(lookup(s, "enabled", true))]

    content {
      name = stage.value.name
      dynamic "action" {
        for_each = stage.value.action
        content {
          name             = action.value["name"]
          owner            = action.value["owner"]
          
          version          = action.value["version"]
          category         = action.value["category"]
          provider         = action.value["provider"]
          input_artifacts  = lookup(action.value, "input_artifacts", [])
          output_artifacts = lookup(action.value, "output_artifacts", [])
          configuration    = lookup(action.value, "configuration", {})
          role_arn         = lookup(action.value, "role_arn", null)
          run_order        = lookup(action.value, "run_order", null)
        }
      }
    }
  }

}

resource "aws_codestarconnections_connection" "codepipeline" {
  name          = "${var.common_name}-${var.image_name}"
  provider_type = "GitHub"
}

# resource "aws_s3_bucket" "codepipeline_bucket" {
#   bucket = "${var.common_name}-${var.image_name}"
# }

# resource "aws_s3_bucket_acl" "codepipeline_bucket_acl" {
#   bucket = aws_s3_bucket.codepipeline_bucket.id
#   acl    = "private"
# }a

resource "aws_iam_role" "codepipeline_role" {
  name = "${var.common_name}-${var.image_name}-codepipeline"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codepipeline.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "codepipeline_policy" {
  name = "${var.common_name}-${var.image_name}-codepipeline"
  role = aws_iam_role.codepipeline_role.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect":"Allow",
      "Action": [
        "s3:GetObject",
        "s3:GetObjectVersion",
        "s3:GetBucketVersioning",
        "s3:PutObjectAcl",
        "s3:PutObject"
      ],
      "Resource": [
        "${aws_s3_bucket.codepipeline_bucket.arn}",
        "${aws_s3_bucket.codepipeline_bucket.arn}/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "codestar-connections:*"
      ],
      "Resource": "${aws_codestarconnections_connection.codepipeline.arn}"
    },
    {
      "Effect": "Allow",
      "Action": [
        "codebuild:BatchGetBuilds",
        "codebuild:StartBuild"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}


#################-- ECR Repo ---#############################

resource "aws_ecr_repository" "repo" {
  name                 = "${var.common_name}-${var.image_name}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}
