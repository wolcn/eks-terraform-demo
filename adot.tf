# Put the adot bits here for now

locals {
  collector_namespace = "adot"
  collector_sa        = "adot-collector"
  collector_cr        = "adot-collector"
  collector_crb       = "adot-collector"
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
resource "kubernetes_namespace_v1" "cert_manager" {
  depends_on = [module.eks]

  metadata {
    name = "cert-manager"
    labels = {
      provisioned_by = "terraform"
    }
  }
}

resource "helm_release" "cert-manager" {
  depends_on      = [kubernetes_namespace_v1.cert_manager]
  name            = "cert-manager"
  repository      = "https://charts.jetstack.io"
  chart           = "cert-manager"
  version         = "v1.18.2"
  namespace       = "cert-manager"
  cleanup_on_fail = true

  set = [{
    name  = "installCRDs"
    value = true
  }]
}
# Addon here

# Currently not compatible with EKS Kubernetes v1.34 so have to stay with v1.33
# Use the following command to check compatibility and get version
#   aws eks describe-addon-versions --addon-name adot
resource "aws_eks_addon" "addon_adot" {
  depends_on                  = [helm_release.cert-manager, aws_iam_role.adot_collector]
  cluster_name                = local.cluster_name
  addon_name                  = "adot"
  addon_version               = "v0.131.0-eksbuild.1"
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
resource "kubernetes_namespace_v1" "collector" {
  depends_on = [module.eks]

  metadata {
    name = local.collector_namespace
    labels = {
      provisioned_by = "terraform"
    }
  }
}

# Service account
resource "kubernetes_service_account_v1" "collector" {
  depends_on = [kubernetes_namespace_v1.collector]
  metadata {
    name      = local.collector_sa
    namespace = local.collector_namespace
  }
}

# Cluster role
resource "kubernetes_cluster_role_v1" "adot_collector" {
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
resource "kubernetes_cluster_role_binding_v1" "adot_collector" {
  depends_on = [kubernetes_cluster_role_v1.adot_collector, kubernetes_service_account_v1.collector]
  metadata {
    name = local.collector_crb
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    # name      = local.collector_cr
    name = kubernetes_cluster_role_v1.adot_collector.id
  }
  subject {
    kind      = "ServiceAccount"
    name      = local.collector_sa
    namespace = local.collector_namespace
  }
}

# Open telemetry collector

resource "kubectl_manifest" "adot_collector" {
  depends_on = [aws_eks_addon.addon_adot, kubernetes_cluster_role_binding_v1.adot_collector]
  yaml_body  = file("./adot/collector.yaml")
}
# Instrumentation

/* Commented out as it is not useful in the target environment
resource "kubectl_manifest" "adot_instrumentation" {
  depends_on = [aws_eks_addon.addon_adot, kubernetes_cluster_role_binding_v1.adot_collector]
  yaml_body  = file("./adot/instrumentation.yaml")
}
*/
