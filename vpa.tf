resource "kubernetes_namespace" "vpa" {
  metadata {
    name = "vpa"

    labels = {
      provisioned_by = "terraform"
    }
  }
}

resource "helm_release" "vpa" {
  depends_on = [
    kubernetes_namespace.vpa
  ]

  name       = "vpa"
  namespace  = kubernetes_namespace.vpa.metadata[0].name
  chart      = "vertical-pod-autoscaler"
  repository = "https://cowboysysop.github.io/charts/"
  version    = "10.2.1"
}
