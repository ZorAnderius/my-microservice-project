#!/bin/bash

set -euo pipefail

echo "[1/6] Підготовка до очищення інфраструктури"

PROJECT_ROOT=$(git rev-parse --show-toplevel)
TERRAFORM_DIR="$PROJECT_ROOT/lesson-8-9/terraform"
S3_BACKEND_DIR="$PROJECT_ROOT/lesson-8-9/terraform/modules/s3-backend"

export VPC_ID=$(terraform -chdir="$TERRAFORM_DIR" output -raw vpc_id 2>/dev/null || echo "")
export AWS_REGION=$(terraform -chdir="$TERRAFORM_DIR" output -raw aws_region 2>/dev/null || echo "")

if [[ -z "$VPC_ID" || -z "$AWS_REGION" ]]; then
  echo "Не вдалося отримати VPC ID або регіон з Terraform output."
  exit 1
fi

clean_helm_apps() {
  echo "Очищення Helm-релізів Jenkins та ArgoCD"

  if ! command -v helm >/dev/null 2>&1; then
    echo "helm не знайдено — пропускаємо Helm cleanup"
    return
  fi

  if helm list -A | grep -q jenkins; then
    echo "Видалення Helm-релізу: jenkins"
    helm uninstall jenkins -n jenkins || true
  fi

  if helm list -A | grep -q argocd; then
    echo "Видалення Helm-релізу: argocd"
    helm uninstall argocd -n argocd || true
  fi
}

clean_kubernetes_namespaces() {
  echo "Видалення namespace-ів Jenkins та ArgoCD"

  if ! command -v kubectl >/dev/null 2>&1; then
    echo "kubectl не знайдено — пропускаємо cleanup namespaces"
    return
  fi

  for ns in jenkins argocd; do
    if kubectl get ns "$ns" &>/dev/null; then
      kubectl delete ns "$ns" --wait=false || true
    fi
  done
}

clean_argocd_crds() {
  echo "Видалення CRD ArgoCD (якщо залишились)"

  if ! command -v kubectl >/dev/null 2>&1; then
    return
  fi

  kubectl get crd | grep 'argoproj.io' | awk '{print $1}' | while read -r crd; do
    kubectl delete crd "$crd" || true
  done
}


clean_load_balancers() {
  echo "===  Видалення Load Balancer-ів, не керованих Terraform ==="

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
      echo "ALB/NLB керується Terraform: $LB_ARN"
    fi
  done

  # --- Classic ELB (aws_elb) ---
  echo "=== Видалення класичних Load Balancer-ів (ELB), не керованих Terraform ==="

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
      echo "ELB керується Terraform: $name"
    fi
  done

  echo "Очікування 20 сек для завершення видалення Load Balancer-ів..."
  sleep 20
}


try_delete_vpc() {
  echo "Спроба видалити VPC: $VPC_ID"

  echo "1. Видалення асоціацій main route table"
  MAIN_RT_ID=$(aws ec2 describe-route-tables \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --region "$AWS_REGION" \
    --query "RouteTables[?Associations[?Main==\`true\`]].RouteTableId" \
    --output text)

  if [[ -n "$MAIN_RT_ID" ]]; then
    echo "Видаляємо route table: $MAIN_RT_ID"
    aws ec2 delete-route-table --route-table-id "$MAIN_RT_ID" --region "$AWS_REGION" || true
  fi

  echo "2. Видалення всіх security groups (крім default)"
  SG_IDS=$(aws ec2 describe-security-groups \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --region "$AWS_REGION" \
    --query "SecurityGroups[?GroupName!='default'].GroupId" \
    --output text)

  for SG_ID in $SG_IDS; do
    echo "Видаляємо security group: $SG_ID"
    aws ec2 delete-security-group --group-id "$SG_ID" --region "$AWS_REGION" || true
  done

  echo "3. Повторна спроба видалити VPC"
  aws ec2 delete-vpc --vpc-id "$VPC_ID" --region "$AWS_REGION" || {
    echo "VPC ще має залежності, видалення не вдалося."
  }
}


clean_blocking_resources() {
  clean_load_balancers
  clean_helm_apps
  clean_kubernetes_namespaces
  clean_argocd_crds
}

cd "$TERRAFORM_DIR"

# [3/6] Очистка обʼєктів які блокують destroy
clean_blocking_resources

echo "[5/6] Terraform destroy: перша спроба"
if terraform destroy -auto-approve; then
  echo "Terraform destroy успішно завершено"
else
  echo "Terraform destroy завершився з помилкою. Аналізуємо..."
  try_delete_vpc
  echo "[5/6] Terraform destroy: повторна спроба"
  terraform destroy -auto-approve || {
    echo "Навіть після очищення Terraform destroy завершився з помилкою."
    exit 1
  }
fi

echo "[6/6] Видалення S3 backend"
cd "$S3_BACKEND_DIR"
BUCKET_NAME=$(terraform output -raw bucket_name 2>/dev/null || echo "")

if [[ -n "$BUCKET_NAME" ]]; then
  echo "Очищення бакету S3: $BUCKET_NAME"
  aws s3 rm "s3://$BUCKET_NAME" --recursive || true
fi

terraform destroy -auto-approve || echo "Не вдалося повністю видалити backend"

echo "Інфраструктура повністю успішно очищена."
