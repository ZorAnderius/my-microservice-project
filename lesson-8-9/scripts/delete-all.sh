#!/bin/bash

set -euo pipefail
set -x  # Увімкнути логування команд

echo "=== [1/6] Підготовка до очищення інфраструктури ==="

PROJECT_ROOT=$(git rev-parse --show-toplevel)
TERRAFORM_DIR="$PROJECT_ROOT/lesson-8-9/terraform"
S3_BACKEND_DIR="$PROJECT_ROOT/lesson-8-9/terraform/modules/s3-backend"

export VPC_ID=$(terraform -chdir="$TERRAFORM_DIR" output -raw vpc_id 2>/dev/null || echo "")
export AWS_REGION=$(terraform -chdir="$TERRAFORM_DIR" output -raw aws_region 2>/dev/null || echo "")

if [[ -z "$VPC_ID" || -z "$AWS_REGION" ]]; then
  echo "❌ Не вдалося отримати VPC ID або регіон з Terraform output."
  exit 1
fi

echo "✓ VPC ID: $VPC_ID"
echo "✓ Region: $AWS_REGION"

echo "=== [2/6] Видалення Load Balancer-ів, не керованих Terraform ==="

# --- ALB/NLB (aws_lb) ---
ALL_LBS=$(aws elbv2 describe-load-balancers --region "$AWS_REGION" \
  --query "LoadBalancers[?VpcId=='$VPC_ID'].LoadBalancerArn" --output text || echo "")

TF_LBS=$(terraform -chdir="$TERRAFORM_DIR" state list | grep aws_lb || true)

TF_LB_ARNS=""
for lb in $TF_LBS; do
  ARN=$(terraform -chdir="$TERRAFORM_DIR" state show -no-color "$lb" 2>/dev/null | grep "arn =" | awk '{print $3}' || true)
  TF_LB_ARNS+="$ARN"$'\n'
done

for LB_ARN in $ALL_LBS; do
  if ! echo "$TF_LB_ARNS" | grep -q "$LB_ARN"; then
    echo "🗑 Видаляємо ALB/NLB (не Terraform): $LB_ARN"
    aws elbv2 delete-load-balancer --region "$AWS_REGION" --load-balancer-arn "$LB_ARN" || true
  else
    echo "✅ ALB/NLB керується Terraform: $LB_ARN"
  fi
done

# --- Classic ELB (aws_elb) ---
echo "=== [2.1/6] Видалення класичних Load Balancer-ів (ELB), не керованих Terraform ==="

CLB_NAMES=$(aws elb describe-load-balancers --region "$AWS_REGION" \
  --query "LoadBalancerDescriptions[?VPCId=='$VPC_ID'].LoadBalancerName" --output text || echo "")

TF_CLBS=$(terraform -chdir="$TERRAFORM_DIR" state list | grep aws_elb || true)

TF_CLB_NAMES=""
for clb in $TF_CLBS; do
  name=$(terraform -chdir="$TERRAFORM_DIR" state show -no-color "$clb" 2>/dev/null | grep "name =" | awk '{print $3}' || true)
  TF_CLB_NAMES+="$name"$'\n'
done

for name in $CLB_NAMES; do
  if ! echo "$TF_CLB_NAMES" | grep -q "^$name$"; then
    echo "🗑 Видаляємо класичний ELB (не Terraform): $name"
    aws elb delete-load-balancer --load-balancer-name "$name" --region "$AWS_REGION" || true
  else
    echo "✅ ELB керується Terraform: $name"
  fi
done

echo "Очікування 20 сек для завершення видалення Load Balancer-ів..."
sleep 20

echo "=== [3/6] Видалення Helm-релізів ==="

uninstall_helm_release() {
  local release_name=$1
  local namespace=$2

  if helm status "$release_name" -n "$namespace" &>/dev/null; then
    echo "🔻 Видаляємо Helm-реліз '$release_name' у namespace '$namespace'"
    helm uninstall "$release_name" -n "$namespace"
  else
    echo "✅ Helm-реліз '$release_name' вже не існує"
  fi
}

uninstall_helm_release "jenkins" "jenkins"
uninstall_helm_release "argocd" "argocd"

echo "=== [4/6] Видалення namespace-ів ==="

delete_namespace() {
  local ns=$1
  if kubectl get ns "$ns" &>/dev/null; then
    echo "🗑 Видаляємо namespace '$ns'"
    kubectl delete ns "$ns" || true
  else
    echo "✅ Namespace '$ns' вже видалений"
  fi
}

delete_namespace "jenkins"
delete_namespace "argocd"

echo "=== [5/6] Terraform destroy ==="
cd "$TERRAFORM_DIR"
terraform destroy -auto-approve

echo "=== [6/6] Видалення S3 backend ==="
cd "$S3_BACKEND_DIR"

BUCKET_NAME=$(terraform output -raw bucket_name 2>/dev/null || echo "")
if [[ -n "$BUCKET_NAME" ]]; then
  echo "🧹 Очищення бакету S3: $BUCKET_NAME"
  aws s3 rm "s3://$BUCKET_NAME" --recursive || true
else
  echo "⚠️ Не вдалося отримати назву S3 бакету"
fi

terraform destroy -auto-approve

echo "✅ Успішно завершено очищення всієї інфраструктури"
