variable "name"          { type = string }
variable "vpc_id"        { type = string }
variable "subnet_ids"    { type = list(string) }
variable "allowed_sg_id" { type = string }
variable "instance_class" { type = string }
variable "multi_az"      { type = bool }
variable "allocated_storage" {
  type    = number
  default = 20
}
variable "deletion_protection" {
  type    = bool
  default = false
}

module "db" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 6.0"

  identifier = "${var.name}-pg"
  engine               = "postgres"
  engine_version       = "16"
  family               = "postgres16"
  major_engine_version = "16"
  instance_class       = var.instance_class
  allocated_storage    = var.allocated_storage
  storage_encrypted    = true

  db_name  = "app"
  username = "app"
  port     = 5432
  manage_master_user_password = true   # password lives in AWS Secrets Manager, never in state/Git

  multi_az               = var.multi_az
  create_db_subnet_group = true
  subnet_ids             = var.subnet_ids
  vpc_security_group_ids = [aws_security_group.db.id]

  backup_retention_period = var.multi_az ? 7 : 1
  deletion_protection     = var.deletion_protection
  skip_final_snapshot     = !var.deletion_protection
}

resource "aws_security_group" "db" {
  name   = "${var.name}-db"
  vpc_id = var.vpc_id
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.allowed_sg_id]   # only the EKS nodes can reach the DB
  }
}

output "endpoint"      { value = module.db.db_instance_address }
output "secret_arn"    { value = module.db.db_instance_master_user_secret_arn }
