#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status

RELEASE_NAME="jenkins"
NAMESPACE="jenkins"

# ========================
# 1. Uninstall Jenkins
# ========================
echo "🔧 Uninstalling Jenkins Helm release..."

if helm status $RELEASE_NAME -n $NAMESPACE > /dev/null 2>&1; then
  helm uninstall $RELEASE_NAME -n $NAMESPACE
else
  echo "Jenkins Helm release not found or already uninstalled."
fi

sleep 5

echo "Deleting all PersistentVolumeClaims in namespace '$NAMESPACE'..."
kubectl delete pvc --all -n $NAMESPACE || true

echo "Deleting namespace '$NAMESPACE'..."
kubectl delete namespace $NAMESPACE || true

echo "Jenkins fully removed."
echo ""

# ===============================
# 2. Destroy main Terraform stack
# ===============================
echo "Running 'terraform destroy' in 'lesson-8-9/terraform'..."

cd "$(git rev-parse --show-toplevel)"
cd lesson-8-9/terraform

terraform destroy -auto-approve

echo "Main Terraform resources destroyed."
echo ""

# ====================================
# 3. Destroy S3 backend Terraform module
# ====================================
echo "Running 'terraform destroy' in 'lesson-8-9/terraform/modules/s3-backend'..."

cd "$(git rev-parse --show-toplevel)"
cd lesson-8-9/terraform/modules/s3-backend

terraform destroy -auto-approve

echo "S3 backend Terraform resources destroyed."
