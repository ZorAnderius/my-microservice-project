#!/bin/bash
set -e

ENV_PATH="$(dirname "$0")/../.env"

if [ -f "$ENV_PATH" ]; then
  export $(grep -v '^#' "$ENV_PATH" | xargs)
else
  echo "Warning: .env file not found at $ENV_PATH"
fi

IMAGE_NAME=$1
DOCKERFILE_PATH=$2
BUILD_CONTEXT=$3
RELEASE_NAME=$4
CHART_PATH=$5

if [ -z "$IMAGE_NAME" ] || [ -z "$DOCKERFILE_PATH" ] || [ -z "$RELEASE_NAME" ] || [ -z "$CHART_PATH" ]; then
  echo "Usage: ./deploy.sh <image-name> <dockerfile-path> <build-context> <release-name> <chart-path>"
  exit 1
fi


if [ -z "$BUILD_CONTEXT" ]; then
  BUILD_CONTEXT=$(dirname "$DOCKERFILE_PATH")
fi
if [ -z "$BUILD_CONTEXT" ]; then
  # Якщо контекст не вказано, беремо директорію з Dockerfile
  BUILD_CONTEXT=$(dirname "$DOCKERFILE_PATH")
fi


echo "Getting AWS info..."
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
export AWS_REGION=$(terraform output -raw aws_region)
export ECR_REPOSITORY=$(terraform output -raw ecr_repo_name)
export EKS_CLUSTER_NAME=$(terraform output -raw eks_cluster_name)

if [ -z "$AWS_REGION" ] || [ -z "$ECR_REPOSITORY" ] || [ -z "$EKS_CLUSTER_NAME" ]; then
  echo "Error: Missing required Terraform outputs"
  exit 1
fi

echo "Updating kubeconfig for EKS cluster: $EKS_CLUSTER_NAME"
aws eks update-kubeconfig --name "$EKS_CLUSTER_NAME" --region "$AWS_REGION"

echo "Checking if cluster is reachable..."
if ! kubectl get nodes >/dev/null 2>&1; then
  echo "Error: Cannot reach Kubernetes cluster '$EKS_CLUSTER_NAME'"
  exit 1
fi

echo "Authenticating to ECR..."
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

echo "Building Docker image: $IMAGE_NAME"
docker build -t "$IMAGE_NAME:latest" -f "$DOCKERFILE_PATH" "$BUILD_CONTEXT"

echo "Tagging image for ECR"
docker tag $IMAGE_NAME:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY:latest

echo "Pushing image to ECR"
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY:latest

echo "Installing PostgreSQL (if not exists)..."
helm upgrade --install postgresql bitnami/postgresql \
  --set auth.username=$POSTGRES_USER \
  --set auth.password=$POSTGRES_PASSWORD \
  --set auth.database=$POSTGRES_DB \
  --set primary.persistence.enabled=false \
  --namespace default

if [ -z "$POSTGRES_PASSWORD" ]; then
  POSTGRES_PASSWORD=$(kubectl get secret postgresql -o jsonpath="{.data.password}" | base64 --decode)
fi

echo "POSTGRES_PASSWORD = '$POSTGRES_PASSWORD'"

echo "Installing Django via Helm..."
helm upgrade --install "$RELEASE_NAME" "$CHART_PATH" \
  --set image.repository="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY" \
  --set image.tag="latest" \
  --set config.POSTGRES_HOST="postgresql.default.svc.cluster.local" \
  --set config.POSTGRES_PORT="$POSTGRES_PORT" \
  --set config.POSTGRES_USER="$POSTGRES_USER" \
  --set config.POSTGRES_DB="$POSTGRES_DB" \
  --set secrets.POSTGRES_PASSWORD="$POSTGRES_PASSWORD"

echo "Deployment complete!"