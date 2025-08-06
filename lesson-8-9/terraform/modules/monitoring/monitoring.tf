resource "helm_release" "kube_prometheus_stack" {
  name             = var.release_name
  namespace        = var.namespace
  repository       = var.repository
  chart            = var.release_name
  version          = var.chart_version
  create_namespace = true

  values = [
    file("${path.module}/values.yaml")
  ]
}