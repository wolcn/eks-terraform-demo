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
  version = "~> 20.33"

  depends_on = [module.vpc, aws_iam_policy.eks_cni_ipv6_policy]

  cluster_name                    = local.cluster_name
  cluster_version                 = local.cluster_version
  enable_irsa                     = false
  vpc_id                          = module.vpc.vpc_id
  subnet_ids                      = module.vpc.private_subnets
  cluster_ip_family               = "ipv6"
  create_cni_ipv6_iam_policy      = false # Set to false and create the policy independently
  cluster_endpoint_public_access  = true  # Not SOC2 compliant but simpler for lab work
  cluster_endpoint_private_access = true
  cluster_upgrade_policy = {
    support_type = "STANDARD" # Set upgrade policy to STANDARD; default is EXTENDED
  }

  # Dev/lab only; disable in prod
  enable_cluster_creator_admin_permissions = true

  cluster_compute_config = {
    enabled    = true # Automode
    node_pools = []   # Explicitly disable default node pools
  }

  # Not all plugins are included in auto mode so add here; e.g. we use the pod identity agent
  cluster_addons = {
    eks-pod-identity-agent = {
      most_recent = true
    }
  }

  # Defined in main.tf
  tags = local.tags
}
