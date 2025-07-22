resource "kubernetes_namespace" "vpa" {
  depends_on = [module.eks]

  metadata {
    name = "vpa"
    labels = {
      provisioned_by = "terraform"
    }
  }
}

resource "helm_release" "metrics_server" {
  depends_on = [module.eks]

  name       = "metrics-server"
  namespace  = "kube-system"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
}

resource "helm_release" "vpa" {
  depends_on = [kubernetes_namespace.vpa]

  name       = "vpa"
  namespace  = kubernetes_namespace.vpa.metadata[0].name
  chart      = "vpa"
  repository = "https://charts.fairwinds.com/stable"
  version    = "4.7.2"
}
