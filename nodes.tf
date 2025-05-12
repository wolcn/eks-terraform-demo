# Set up node categories
# Originally used the default classes and pools provided by automode, but
# more control was needed so locally defined categories are used in the demo instead

# EKS auto mode node classes require a role; generate a unique name
resource "aws_iam_role" "eks_nodeclass" {
  # The full name of the role is needed when creating the node class
  name_prefix = "${local.cluster_name}-nodeclass-"
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
          Service = ["ec2.amazonaws.com"]
        }
      },
    ]
  })
}

# Attach a couple of standard AWS IAM policies
resource "aws_iam_role_policy_attachment" "ec2_container_registry_access" {
  role       = aws_iam_role.eks_nodeclass.id
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly"
}
resource "aws_iam_role_policy_attachment" "work_node_minimal" {
  role       = aws_iam_role.eks_nodeclass.id
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodeMinimalPolicy"
}

# Custom tags for EKS Auto Mode resources require a few extra permissions;
# following policy is based on the example given in the AWS documentation
# https://docs.aws.amazon.com/eks/latest/userguide/auto-learn-iam.html
# Custom tags are one of the reasons for defining own node classes; not
# possible with the predefined node classes

resource "aws_iam_role_policy" "eks_custom_tags" {
  name = "eks-custom-tags"
  role = aws_iam_role.eks_nodeclass.id
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "Compute",
        "Effect" : "Allow",
        "Action" : [
          "ec2:CreateFleet",
          "ec2:RunInstances",
          "ec2:CreateLaunchTemplate"
        ],
        "Resource" : "*",
        "Condition" : {
          "StringEquals" : {
            "aws:RequestTag/eks:eks-cluster-name" : "${local.cluster_name}"
          },
          "StringLike" : {
            "aws:RequestTag/eks:kubernetes-node-class-name" : "*",
            "aws:RequestTag/eks:kubernetes-node-pool-name" : "*"
          }
        }
      },
      {
        "Sid" : "Storage",
        "Effect" : "Allow",
        "Action" : [
          "ec2:CreateVolume",
          "ec2:CreateSnapshot"
        ],
        "Resource" : [
          "arn:aws:ec2:*:*:volume/*",
          "arn:aws:ec2:*:*:snapshot/*"
        ],
        "Condition" : {
          "StringEquals" : {
            "aws:RequestTag/eks:eks-cluster-name" : "${local.cluster_name}"
          }
        }
      },
      {
        "Sid" : "Networking",
        "Effect" : "Allow",
        "Action" : "ec2:CreateNetworkInterface",
        "Resource" : "*",
        "Condition" : {
          "StringEquals" : {
            "aws:RequestTag/eks:eks-cluster-name" : "${local.cluster_name}"
          },
          "StringLike" : {
            "aws:RequestTag/eks:kubernetes-cni-node-name" : "*"
          }
        }
      },
      {
        "Sid" : "LoadBalancer",
        "Effect" : "Allow",
        "Action" : [
          "elasticloadbalancing:CreateLoadBalancer",
          "elasticloadbalancing:CreateTargetGroup",
          "elasticloadbalancing:CreateListener",
          "elasticloadbalancing:CreateRule",
          "ec2:CreateSecurityGroup"
        ],
        "Resource" : "*",
        "Condition" : {
          "StringEquals" : {
            "aws:RequestTag/eks:eks-cluster-name" : "${local.cluster_name}"
          }
        }
      },
      {
        "Sid" : "ShieldProtection",
        "Effect" : "Allow",
        "Action" : [
          "shield:CreateProtection"
        ],
        "Resource" : "*",
        "Condition" : {
          "StringEquals" : {
            "aws:RequestTag/eks:eks-cluster-name" : "${local.cluster_name}"
          }
        }
      },
      {
        "Sid" : "ShieldTagResource",
        "Effect" : "Allow",
        "Action" : [
          "shield:TagResource"
        ],
        "Resource" : "arn:aws:shield::*:protection/*",
        "Condition" : {
          "StringEquals" : {
            "aws:RequestTag/eks:eks-cluster-name" : "${local.cluster_name}"
          }
        }
      }
    ]
  })
}

# The role needs an access entry configuration also
# Delayed until the EKS cluster is available
resource "aws_eks_access_entry" "nodeclass" {
  depends_on    = [module.eks.cluster_name]
  cluster_name  = module.eks.cluster_name
  principal_arn = aws_iam_role.eks_nodeclass.arn
  type          = "EC2" # For EKS Auto Mode custom node clases
}

# And an access policy association
resource "aws_eks_access_policy_association" "nodeclass" {
  depends_on    = [aws_iam_role.eks_nodeclass]
  cluster_name  = module.eks.cluster_name
  principal_arn = aws_iam_role.eks_nodeclass.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSAutoNodePolicy"

  access_scope {
    type       = "cluster"
    namespaces = []
  }
}

# Now the node class manifest files with the role from above
# The dependency module.eks.cluster_id is supposed to wait until the cluster is available before accessing it
# Provisioning sometimes works without it so not 100% verified yet
# The Security Group is the one used by the default node classes with the prefix "eks-cluster-sg-${local.cluster_name}-"
resource "kubectl_manifest" "nodeclass_core" {
  depends_on = [
    module.eks.cluster_id,
    aws_eks_access_entry.nodeclass,
    aws_eks_access_policy_association.nodeclass
  ]
  yaml_body = templatefile("./nodes/core-class.tftpl", {
    role_id           = aws_iam_role.eks_nodeclass.id
    cluster_name      = local.cluster_name
    security_group_id = module.eks.cluster_primary_security_group_id
  })
}

resource "kubectl_manifest" "nodeclass_application" {
  depends_on = [
    module.eks.cluster_id,
    aws_eks_access_entry.nodeclass,
    aws_eks_access_policy_association.nodeclass
  ]
  yaml_body = templatefile("./nodes/application-class.tftpl", {
    role_id           = aws_iam_role.eks_nodeclass.id
    cluster_name      = local.cluster_name
    security_group_id = module.eks.cluster_primary_security_group_id
  })
}

resource "kubectl_manifest" "nodeclass_gpu" {
  depends_on = [
    module.eks.cluster_id,
    aws_eks_access_entry.nodeclass,
    aws_eks_access_policy_association.nodeclass
  ]
  yaml_body = templatefile("./nodes/gpu-class.tftpl", {
    role_id           = aws_iam_role.eks_nodeclass.id
    cluster_name      = local.cluster_name
    security_group_id = module.eks.cluster_primary_security_group_id
  })
}

resource "kubectl_manifest" "nodepool_core" {
  depends_on = [kubectl_manifest.nodeclass_core]
  yaml_body  = file("./nodes/core-pool.yaml")
}

resource "kubectl_manifest" "nodepool_application" {
  depends_on = [kubectl_manifest.nodeclass_application]
  yaml_body  = file("./nodes/application-pool.yaml")
}

resource "kubectl_manifest" "nodepool_gpu" {
  depends_on = [kubectl_manifest.nodeclass_gpu]
  yaml_body  = file("./nodes/gpu-pool.yaml")
}
