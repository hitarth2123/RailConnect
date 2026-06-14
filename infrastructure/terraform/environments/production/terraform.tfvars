# Terraform Variables for Production Environment
# Copy to terraform.tfvars and customize for your AWS account

aws_region = "ap-south-1"
environment = "production"

# VPC Configuration
vpc_cidr             = "10.0.0.0/16"
private_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
public_subnet_cidrs  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

# EKS Configuration
eks_cluster_version     = "1.28"
eks_node_desired_size   = 3
eks_node_min_size       = 2
eks_node_max_size       = 10
eks_node_instance_types = ["t3.medium", "t3.large"]

# RDS PostgreSQL Configuration
# ⚠️ IMPORTANT: Change password in production!
rds_allocated_storage = 20
rds_instance_class    = "db.t3.micro"
rds_engine_version    = "15.3"
rds_database_name     = "railconnect"
rds_username          = "admin"
rds_password          = "RailConnect2026!"  # Change this!

# ElastiCache Redis Configuration
enable_redis           = true
redis_node_type        = "cache.t3.micro"
redis_num_cache_nodes  = 2

# Tags applied to all resources
tags = {
  Project     = "railconnect"
  Environment = "production"
  ManagedBy   = "terraform"
  CostCenter  = "engineering"
  Owner       = "devops-team"
}
