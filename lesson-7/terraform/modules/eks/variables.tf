variable "region" {
  type        = string
  description = "AWS region for deployment"
  default     = "eu-central-1"
}

variable "cluster_name" {
  type        = string
  description = "EKS cluster name"
  default     = "example_eks_cluster"
}

variable "subnet_ids" {
  type        = list(string)
  description = "List of subnet IDs for the EKS cluster"
}

variable "node_group_name" {
  type        = string
  description = "Name of the node group"
  default     = "general"
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type for the worker nodes"
  default     = "t3.medium"
}

variable "capacity_type" {
  type = string
  description = "Capacity type"
  default = "ON_DEMAND"
}

variable "desired_size" {
  type        = number
  description = "Desired number of worker nodes"
  default     = 2
}

variable "max_size" {
  type        = number
  description = "Maximum number of worker nodes"
  default     = 3
}

variable "min_size" {
  type        = number
  description = "Minimum number of worker number"
  default     = 1
}
