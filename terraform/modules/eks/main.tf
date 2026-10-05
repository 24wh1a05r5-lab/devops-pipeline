variable "name"            { type = string }
variable "vpc_id"          { type = string }
variable "subnet_ids"      { type = list(string) }
variable "instance_types"  { type = list(string) }
variable "min_size"        { type = number }
variable "max_size"        { type = number }
variable "desired_size"    { type = number }
variable "capacity_type"   {
  type    = string
  default = "ON_DEMAND" # SPOT for dev to save cost
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.name
  cluster_version = "1.30"
  vpc_id          = var.vpc_id
  subnet_ids      = var.subnet_ids

  cluster_endpoint_public_access           = true
  enable_cluster_creator_admin_permissions = true

  eks_managed_node_groups = {
    default = {
      instance_types = var.instance_types
      capacity_type  = var.capacity_type
      min_size       = var.min_size
      max_size       = var.max_size
      desired_size   = var.desired_size
    }
  }
}

output "cluster_name"     { value = module.eks.cluster_name }
output "cluster_endpoint" { value = module.eks.cluster_endpoint }
output "node_sg_id"       { value = module.eks.node_security_group_id }
