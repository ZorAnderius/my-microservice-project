output "grafana_url" {
  value = "http://${helm_release.kube_prometheus_stack.name}-grafana.${var.namespace}.svc.cluster.local"
}
