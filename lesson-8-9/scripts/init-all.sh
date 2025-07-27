#!/bin/bash

set -e
set -o pipefail

PROJECT_ROOT=$(git rev-parse --show-toplevel)

echo "1. Ініціалізація S3 бакету (terraform apply у модулі s3-backend)..."
pushd "$PROJECT_ROOT/lesson-8-9/terraform/modules/s3-backend" > /dev/null
terraform init
terraform apply -auto-approve
popd > /dev/null

echo "2. Оновлення залежностей Helm чарта для argo_apps..."
pushd "$PROJECT_ROOT/lesson-8-9/terraform/modules/argo_cd/charts" > /dev/null
helm dependency update
popd > /dev/null

echo "3. Деплой інфраструктури (terraform apply)..."
pushd "$PROJECT_ROOT/lesson-8-9/terraform" > /dev/null
terraform init
terraform apply -auto-approve
popd > /dev/null

echo "4. Оновлення kubeconfig для EKS..."

export AWS_REGION=$(terraform -chdir="$PROJECT_ROOT/lesson-8-9/terraform" output -raw aws_region)
export EKS_CLUSTER_NAME=$(terraform -chdir="$PROJECT_ROOT/lesson-8-9/terraform" output -raw eks_cluster_name)

if [ -z "$AWS_REGION" ] || [ -z "$EKS_CLUSTER_NAME" ]; then
  echo "Error: Missing required Terraform outputs"
  exit 1
fi

aws eks update-kubeconfig --name "$EKS_CLUSTER_NAME" --region "$AWS_REGION"

echo "Kubeconfig оновлено!"
echo ""
echo "🔗 Збираємо доступи до сервісів..."

# --- ArgoCD ---
ARGOCD_COMMAND=$(terraform -chdir="$PROJECT_ROOT/lesson-8-9/terraform" output -raw argocd_admin_password 2>/dev/null || echo "")

ARGOCD_PASSWORD=""
if [[ -n "$ARGOCD_COMMAND" ]]; then
  CLEAN_COMMAND=$(echo "$ARGOCD_COMMAND" | sed 's/^Run: //')
  ARGOCD_PASSWORD=$(eval "$CLEAN_COMMAND" 2>/dev/null || echo "Невдалось отримати пароль")
fi

ARGOCD_URL=$(kubectl get svc -n argocd -l app.kubernetes.io/name=argocd-server \
  -o jsonpath="http://{.items[0].status.loadBalancer.ingress[0].hostname}" 2>/dev/null || echo "Не знайдено")

echo ""
echo "ArgoCD:"
echo "   ➤ URL: $ARGOCD_URL"
echo "   ➤ Логін: admin"
echo "   ➤ Пароль: $ARGOCD_PASSWORD"
echo ""

# --- Jenkins ---
JENKINS_NAMESPACE=$(terraform -chdir="$PROJECT_ROOT/lesson-8-9/terraform" output -raw jenkins_namespace 2>/dev/null || echo "jenkins")
JENKINS_URL=$(kubectl get svc -n "$JENKINS_NAMESPACE" -l app.kubernetes.io/component=jenkins-controller \
  -o jsonpath="http://{.items[0].status.loadBalancer.ingress[0].hostname}" 2>/dev/null || echo "Не знайдено")

echo "Jenkins:"
echo "   ➤ URL: $JENKINS_URL"
echo "   ➤ Логін: admin"
echo "   ➤ Пароль: admin123"

# --- Django App ---
DJANGO_URL=$(kubectl get svc -n default django-app -o jsonpath="http://{.status.loadBalancer.ingress[0].hostname}" 2>/dev/null || echo "Не знайдено")

echo "Django App:"
echo "   ➤ URL: $DJANGO_URL"
echo ""

echo "Успішно завершено встановлення всіх компонентів!"