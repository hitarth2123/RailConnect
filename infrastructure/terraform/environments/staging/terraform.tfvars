aws_region  = "ap-south-1"
environment = "staging"

# VPC — separate CIDR from production to avoid overlap
vpc_cidr             = "10.1.0.0/16"
private_subnet_cidrs = ["10.1.1.0/24", "10.1.2.0/24", "10.1.3.0/24"]
public_subnet_cidrs  = ["10.1.101.0/24", "10.1.102.0/24", "10.1.103.0/24"]

# EKS — smaller, fewer nodes than production
eks_cluster_version     = "1.32"
eks_node_desired_size   = 2
eks_node_min_size       = 1
eks_node_max_size       = 5
eks_node_instance_types = ["t3.micro"]

# RDS — no multi-AZ, no backups (free tier)
rds_allocated_storage = 20
rds_instance_class    = "db.t3.micro"
rds_engine_version    = "15.18"
rds_database_name     = "railconnect"
rds_username          = "railconnect_admin"
rds_password          = "RailConnectStaging2026!"  # Change this!

# Redis — single node
enable_redis    = true
redis_node_type = "cache.t3.micro"

tags = {
  Project     = "railconnect"
  Environment = "staging"
  ManagedBy   = "terraform"
  CostCenter  = "engineering"
  Owner       = "devops-team"
}
