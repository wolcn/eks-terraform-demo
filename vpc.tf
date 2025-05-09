# VPC Module
# Simple VPC for the demo cluster

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.8.1"

  name = local.vpc_name
  cidr = local.vpc_cidr
  azs  = local.vpc_azs

  create_database_subnet_group    = false
  create_elasticache_subnet_group = false
  create_redshift_subnet_group    = false

  enable_ipv6 = true

  enable_nat_gateway     = true
  single_nat_gateway     = false
  one_nat_gateway_per_az = true

  # Currently only used for NAT and EIGW
  public_subnet_assign_ipv6_address_on_creation = true
  public_subnets                                = ["10.0.1.0/26", "10.0.2.0/26", "10.0.3.0/26"]
  public_subnet_ipv6_prefixes                   = [0, 1, 2]
  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_assign_ipv6_address_on_creation = true
  private_subnets                                = ["10.0.10.0/24", "10.0.11.0/24", "10.0.12.0/24"]
  private_subnet_ipv6_prefixes                   = [3, 4, 5]
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" : "1"
  }

  intra_subnet_assign_ipv6_address_on_creation = true
  intra_subnets                                = ["10.0.80.0/26", "10.0.80.64/26", "10.0.80.128/26"]
  intra_subnet_ipv6_prefixes                   = [6, 7, 8]
}
