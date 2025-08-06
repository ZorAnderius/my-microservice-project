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

TFVARS_FILE="$PROJECT_ROOT/lesson-8-9/terraform/terraform.tfvars"

get_tfvar() {
  local var_name="$1"
  awk -F '=' -v var="$var_name" '$1 ~ var { gsub(/^[ \t]+|[ \t]+$/, "", $2); gsub(/^"|"$/, "", $2); print $2 }' "$TFVARS_FILE" | head -n1
}

echo "Парсимо змінні з terraform.tfvars..."

POSTGRES_USER=$(get_tfvar "rds_username")
POSTGRES_DB=$(get_tfvar "rds_database_name")
POSTGRES_PASSWORD=$(get_tfvar "rds_password")
POSTGRES_PORT=$(get_tfvar "db_port")
POSTGRES_PORT="${POSTGRES_PORT:-5432}"

echo "Отримуємо POSTGRES_HOST з terraform output..."
POSTGRES_HOST=$(terraform -chdir="$PROJECT_ROOT/lesson-8-9/terraform" output -raw rds_endpoint)

: "${POSTGRES_HOST:?Помилка: POSTGRES_HOST не заданий}"
: "${POSTGRES_DB:?Помилка: POSTGRES_DB не заданий у terraform.tfvars}"
: "${POSTGRES_USER:?Помилка: POSTGRES_USER не заданий у terraform.tfvars}"
: "${POSTGRES_PASSWORD:?Помилка: POSTGRES_PASSWORD не заданий у terraform.tfvars}"

SECRET_NAMESPACE="default"
SECRET_NAME="django-app-secret"

kubectl apply -n "$SECRET_NAMESPACE" -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: $SECRET_NAME
type: Opaque
stringData:
  POSTGRES_HOST: "$POSTGRES_HOST"
  POSTGRES_DB: "$POSTGRES_DB"
  POSTGRES_USER: "$POSTGRES_USER"
  POSTGRES_PASSWORD: "$POSTGRES_PASSWORD"
  POSTGRES_PORT: "$POSTGRES_PORT"
EOF

echo "Секрет $SECRET_NAME оновлено в namespace $SECRET_NAMESPACE"

echo "Перевіряємо і створюємо/оновлюємо Kubernetes секрет: $SECRET_NAME у namespace $SECRET_NAMESPACE"

kubectl create secret generic "$SECRET_NAME" \
  --namespace "$SECRET_NAMESPACE" \
  --from-literal=POSTGRES_HOST="$POSTGRES_HOST" \
  --from-literal=POSTGRES_DB="$POSTGRES_DB" \
  --from-literal=POSTGRES_USER="$POSTGRES_USER" \
  --from-literal=POSTGRES_PASSWORD="$POSTGRES_PASSWORD" \
  --from-literal=POSTGRES_PORT="$POSTGRES_PORT" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Секрет $SECRET_NAME оновлено!"

# --- Grafana ---
echo ""
echo "Налаштування доступу до Grafana..."

GRAFANA_NAMESPACE=$(terraform -chdir="$PROJECT_ROOT/lesson-8-9/terraform" output -raw grafana_namespace 2>/dev/null || echo "monitoring")
GRAFANA_SERVICE_NAME=$(kubectl get svc -n "$GRAFANA_NAMESPACE" -l app.kubernetes.io/name=grafana -o jsonpath="{.items[0].metadata.name}" 2>/dev/null)

if [ -z "$GRAFANA_SERVICE_NAME" ]; then
  echo "Grafana service не знайдено у namespace '$GRAFANA_NAMESPACE'"
else
  echo "Знайдено Grafana service: $GRAFANA_SERVICE_NAME"

  # Знаходимо вільний локальний порт
  echo "Шукаємо вільний локальний порт..."
  function find_free_port() {
    for port in {3000..3999}; do
      if ! lsof -i :$port >/dev/null 2>&1; then
        echo $port
        return
      fi
    done
    echo ""
  }

  LOCAL_PORT=$(find_free_port)

  if [ -z "$LOCAL_PORT" ]; then
    echo "Не знайдено вільного порту для port-forward у діапазоні 3000–3999"
    exit 1
  fi

  echo "🔌 Використовуємо локальний порт: $LOCAL_PORT"
  echo "Старт port-forward до Grafana у фоновому режимі..."
  kubectl port-forward svc/"$GRAFANA_SERVICE_NAME" "$LOCAL_PORT":80 -n "$GRAFANA_NAMESPACE" >/dev/null 2>&1 &
  GRAFANA_PORT_FORWARD_PID=$!

  # Чекаємо, поки порт-форвард встановиться
  sleep 5

  echo "Отримуємо Grafana пароль з Kubernetes секрету..."
  GRAFANA_PASSWORD=$(kubectl get secret -n "$GRAFANA_NAMESPACE" "$GRAFANA_SERVICE_NAME" -o jsonpath="{.data.admin-password}" 2>/dev/null | base64 --decode)

  if [ -z "$GRAFANA_PASSWORD" ]; then
    GRAFANA_PASSWORD=" Не вдалось отримати"
  fi

  echo ""
  echo "Grafana:"
  echo "   ➤ URL: http://localhost:$LOCAL_PORT"
  echo "   ➤ Логін: admin"
  echo "   ➤ Пароль: $GRAFANA_PASSWORD"
  echo ""
fi
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