terraform {
  required_version = ">= 1.6"
  required_providers { aws = { source = "hashicorp/aws", version = "~> 5.0" } }

  # Remote state + locking. Create the bucket/table once with terraform/bootstrap,
  # then replace the bucket name below (backend blocks cannot use variables).
  backend "s3" {
    bucket         = "CHANGE-ME-tfstate"
    key            = "staging/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = var.region
  default_tags { tags = { Project = "devops-pipeline", Environment = "staging", ManagedBy = "terraform" } }
}

variable "region" { type = string }
variable "cidr" { type = string }
variable "node_instance_types" { type = list(string) }
variable "node_min" { type = number }
variable "node_max" { type = number }
variable "node_desired" { type = number }
variable "node_capacity_type" { type = string }
variable "db_instance_class" { type = string }
variable "db_multi_az" { type = bool }
variable "single_nat" { type = bool }
variable "db_deletion_protection" { type = bool }

locals { name = "devops-staging" }

data "aws_availability_zones" "available" { state = "available" }

module "vpc" {
  source     = "../../modules/vpc"
  name       = local.name
  cidr       = var.cidr
  azs        = slice(data.aws_availability_zones.available.names, 0, 3)
  single_nat = var.single_nat
}

module "eks" {
  source         = "../../modules/eks"
  name           = local.name
  vpc_id         = module.vpc.vpc_id
  subnet_ids     = module.vpc.private_subnets
  instance_types = var.node_instance_types
  min_size       = var.node_min
  max_size       = var.node_max
  desired_size   = var.node_desired
  capacity_type  = var.node_capacity_type
}

module "rds" {
  source              = "../../modules/rds"
  name                = local.name
  vpc_id              = module.vpc.vpc_id
  subnet_ids          = module.vpc.private_subnets
  allowed_sg_id       = module.eks.node_sg_id
  instance_class      = var.db_instance_class
  multi_az            = var.db_multi_az
  deletion_protection = var.db_deletion_protection
}

output "cluster_name"   { value = module.eks.cluster_name }
output "db_endpoint"    { value = module.rds.endpoint }
output "db_secret_arn"  { value = module.rds.secret_arn }
