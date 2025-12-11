# EKS and related modules

# Create the CNI policy independently from the EKS clusters; important as the name is hardcoded
# in the EKS modules plus can only be provisioned once by Terraform
# Recommended by terraform developers when using multiple clusters and good practice in general

resource "aws_iam_policy" "eks_cni_ipv6_policy" {
  name        = "AmazonEKS_CNI_IPv6_Policy"
  description = "Standalone AmazonEKS_CNI_IPv6_Policy created with Terraform"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ec2:DescribeTags",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceTypes",
          "ec2:AssignIpv6Addresses"
        ]
        Effect   = "Allow"
        Resource = "*"
        Sid      = "AssignDescribe"
      },
      {
        Action   = "ec2:CreateTags"
        Effect   = "Allow"
        Resource = "arn:aws:ec2:*:*:network-interface/*"
        Sid      = "Createtags"
      }
    ]
  })
}

# Automode module with both default pools disabled
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  depends_on = [module.vpc, aws_iam_policy.eks_cni_ipv6_policy]

  name                       = local.cluster_name
  kubernetes_version         = local.cluster_version
  enable_irsa                = false
  vpc_id                     = module.vpc.vpc_id
  subnet_ids                 = module.vpc.private_subnets
  ip_family                  = "ipv6"
  create_cni_ipv6_iam_policy = false # Set to false and create the policy independently
  endpoint_public_access     = true  # Not SOC2 compliant but simpler for lab work
  endpoint_private_access    = true
  upgrade_policy = {
    support_type = "STANDARD" # Set upgrade policy to STANDARD; default is EXTENDED
  }

  # Dev/lab only; disable in prod
  enable_cluster_creator_admin_permissions = true

  compute_config = {
    enabled = true # Automode
    # Built-in nodepools not added unless listed
    # node_pools = ["system", "general-purpose"]
  }

  # Not all plugins are included in auto mode so add here; e.g. we use the pod identity agent
  addons = {
    eks-pod-identity-agent = {
      most_recent = true
    }
  }

  # Defined in main.tf
  tags = local.tags
}
