resource "aws_ecr_repository" "repository" {
  name = var.ecr_name
  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }

  force_delete = true

  tags = {
    Name = var.ecr_name
  }
}

resource "aws_iam_role" "ecr_role" {
  name = "ecr-access-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"  # або "ecs-tasks.amazonaws.com" якщо це роль для ECS
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_policy" "ecr_access_policy" {
  name        = "ECRAccessPolicy"
  description = "Policy to allow access to ECR"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:DescribeRepositories"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecr_attach" {
  role       = aws_iam_role.ecr_role.name
  policy_arn = aws_iam_policy.ecr_access_policy.arn
}
