resource "helm_release" "argo_cd" {
  name       = var.name
  namespace  = var.namespace
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.chart_version

  values = [
    file("${path.module}/values.yaml")
  ]

  create_namespace = true
}

resource "helm_release" "argo_apps" {
  name             = "${var.name}-apps"
  chart            = "${path.module}/charts"
  namespace        = var.namespace
  create_namespace = false

  values = [
    templatefile("${path.module}/charts/values.yaml.tmpl", {
      github_repo_url = var.github_repo_url
      github_user     = var.github_user
      github_token    = var.github_token
      github_branch   = var.github_branch
      ecr_repo_url    = var.ecr_repo_url
    })
  ]

  depends_on = [helm_release.argo_cd]
}
