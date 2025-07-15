#IAM-role for EKS-cluster
resource "aws_iam_role" "eks" {
  name               = "${var.cluster_name}-eks-cluster"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Action    = "sts:AssumeRole"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })
}

#connect IAM-role and AmazonEKSClusterPolicy
resource "aws_iam_role_policy_attachment" "eks" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks.name
}

#creation of the EKS-cluster
resource "aws_eks_cluster" "eks" {
  # Назва кластера
  name = var.cluster_name

  # ARN IAM-ролі, яка потрібна для керування кластером
  role_arn = aws_iam_role.eks.arn

  # Налаштування мережі (VPC)
  vpc_config {
    endpoint_private_access = true            # Включає приватний доступ до API-сервера
    endpoint_public_access  = true            # Включає публічний доступ до API-сервера
    subnet_ids              = var.subnet_ids  # Список підмереж, де буде працювати EKS
  }

  # Налаштування доступу до EKS-кластера
    access_config {
      authentication_mode = "API"                         # Автентифікація через API
      bootstrap_cluster_creator_admin_permissions = true  # Надає адміністративні права користувачу, який створив кластер
    }

    # Залежність від IAM-політики для ролі EKS
    depends_on = [ aws_iam_role_policy_attachment.eks ]
}
