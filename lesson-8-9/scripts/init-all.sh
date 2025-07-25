#!/bin/bash

set -e
set -o pipefail

PROJECT_ROOT=$(git rev-parse --show-toplevel)

echo "1. Ініціалізація S3 бакету (terraform apply у модулі s3-backend)..."
pushd "$PROJECT_ROOT/lesson-8-9/terraform/modules/s3-backend" > /dev/null
terraform init
terraform apply -auto-approve
popd > /dev/null

echo "2. Деплой інфраструктури (terraform apply)..."
pushd "$PROJECT_ROOT/lesson-8-9/terraform" > /dev/null
terraform init
terraform apply -auto-approve
popd > /dev/null

echo "3. Оновлення kubeconfig для EKS..."

export AWS_REGION=$(terraform -chdir="$PROJECT_ROOT/lesson-8-9/terraform" output -raw aws_region)
export EKS_CLUSTER_NAME=$(terraform -chdir="$PROJECT_ROOT/lesson-8-9/terraform" output -raw eks_cluster_name)

if [ -z "$AWS_REGION" ] || [ -z "$EKS_CLUSTER_NAME" ]; then
  echo "Error: Missing required Terraform outputs"
  exit 1
fi

aws eks update-kubeconfig --name "$EKS_CLUSTER_NAME" --region "$AWS_REGION"

echo "Kubeconfig оновлено!"
echo "Все встановлено успішно та готово до роботи!"
