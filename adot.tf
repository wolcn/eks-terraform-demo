# Put the adot bits here for now

locals {
  collector_namespace = "opentelemetry"
  collector_sa        = "opentelemetry-collector"
  collector_cr        = "opentelemetry-collector"
  collector_crb       = "opentelemetry-collector"
}

# The collector role
resource "aws_iam_role" "adot_collector" {
  # The full name of the role is needed when creating the node class
  # name_prefix = "${local.cluster_name}-adot-collector-"
  name = "adot-collector"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
        Effect = "Allow"
        Principal = {
          Service = ["pods.eks.amazonaws.com"]
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "xray_write_only_access" {
  role       = aws_iam_role.adot_collector.id
  policy_arn = "arn:aws:iam::aws:policy/AWSXrayWriteOnlyAccess"
}
resource "aws_iam_role_policy_attachment" "cloud_watch_agent_server_policy" {
  role       = aws_iam_role.adot_collector.id
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}


# Cert manager here
resource "kubernetes_namespace" "cert_manager" {
  depends_on = [module.eks]

  metadata {
    name = "cert-manager"
    labels = {
      provisioned_by = "terraform"
    }
  }
}

resource "helm_release" "cert-manager" {
  depends_on      = [kubernetes_namespace.cert_manager]
  name            = "cert-manager"
  repository      = "https://charts.jetstack.io"
  chart           = "cert-manager"
  version         = "v1.18.2"
  namespace       = "cert-manager"
  cleanup_on_fail = true

  set {
    name  = "installCRDs"
    value = true
  }
}
# Addon here

# Currently not available for EKS Kubernetes v1.33 so have to stay with v1.32
resource "aws_eks_addon" "addon_adot" {
  depends_on                  = [helm_release.cert-manager, aws_iam_role.adot_collector]
  cluster_name                = local.cluster_name
  addon_name                  = "adot"
  addon_version               = "v0.117.0-eksbuild.1"
  configuration_values        = "{\"manager\":{\"resources\":{\"limits\":{\"cpu\":\"200m\"}}}}" # ?
  resolve_conflicts_on_update = "OVERWRITE"
}

# Collector specific definitions

resource "aws_eks_pod_identity_association" "adot_collector" {
  depends_on      = [module.eks, aws_iam_role.adot_collector]
  cluster_name    = local.cluster_name
  namespace       = local.collector_namespace
  service_account = local.collector_sa
  role_arn        = aws_iam_role.adot_collector.arn
}

# Namespace
resource "kubernetes_namespace" "collector" {
  depends_on = [module.eks]

  metadata {
    name = local.collector_namespace
    labels = {
      provisioned_by = "terraform"
    }
  }
}

# Service account
resource "kubernetes_service_account" "collector" {
  depends_on = [kubernetes_namespace.collector]
  metadata {
    name      = local.collector_sa
    namespace = local.collector_namespace
  }
}

# Cluster role
resource "kubernetes_cluster_role" "opentelemetry_collector" {
  depends_on = [module.eks]
  metadata {
    name = local.collector_cr
  }

  rule {
    api_groups = [""]
    resources  = ["nodes", "nodes/proxy", "services", "endpoints", "pods"]
    verbs      = ["get", "list", "watch"]
  }
  rule {
    api_groups = ["extensions"]
    resources  = ["ingresses"]
    verbs      = ["get", "list", "watch"]
  }
  rule {
    non_resource_urls = ["/metrics"]
    verbs             = ["get"]
  }
}

# Cluster role binding
resource "kubernetes_cluster_role_binding" "opentelemetry_collector" {
  depends_on = [kubernetes_cluster_role.opentelemetry_collector, kubernetes_service_account.collector]
  metadata {
    name = local.collector_crb
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    # name      = local.collector_cr
    name = kubernetes_cluster_role.opentelemetry_collector.id
  }
  subject {
    kind      = "ServiceAccount"
    name      = local.collector_sa
    namespace = local.collector_namespace
  }
}

# Open telemetry collector

resource "kubectl_manifest" "opentelemetry_collector" {
  depends_on = [aws_eks_addon.addon_adot, kubernetes_cluster_role_binding.opentelemetry_collector]
  yaml_body  = file("./adot/collector.yaml")
}
# Instrumentation

resource "kubectl_manifest" "opentelemetry_instrumentation" {
  depends_on = [aws_eks_addon.addon_adot, kubernetes_cluster_role_binding.opentelemetry_collector]
  yaml_body  = file("./adot/instrumentation.yaml")
}
