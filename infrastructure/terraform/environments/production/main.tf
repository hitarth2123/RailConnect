# Main Terraform Configuration for RailConnect Production Environment
# Provisions: VPC, EKS Cluster, RDS PostgreSQL, ElastiCache Redis, IAM roles

# VPC Module
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "5.0.0"

  name = "railconnect-prod-vpc"
  cidr = var.vpc_cidr

  azs             = slice(data.aws_availability_zones.available.names, 0, 3)
  private_subnets = var.private_subnet_cidrs
  public_subnets  = var.public_subnet_cidrs

  enable_nat_gateway   = true
  enable_vpn_gateway   = false
  enable_dns_hostnames = true
  single_nat_gateway   = false # One NAT per AZ for HA

  # Kubernetes specific tags
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"             = "1"
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  }

  public_subnet_tags = {
    "kubernetes.io/role/elb"                      = "1"
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  }

  tags = local.tags
}

# EKS Cluster Module
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.16.0"

  cluster_name    = local.cluster_name
  cluster_version = var.eks_cluster_version

  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = concat(module.vpc.private_subnets, module.vpc.public_subnets)

  # Cluster logging
  cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  # Cluster security group rules
  cluster_security_group_additional_rules = {
    ingress_nodes_ephemeral_ports_tcp = {
      description                = "Nodes on ephemeral ports"
      protocol                   = "tcp"
      from_port                  = 1025
      to_port                    = 65535
      type                       = "ingress"
      source_security_group_id   = module.eks.node_security_group_id
    }
  }

  # Node group configuration
  eks_managed_node_groups = {
    general = {
      name            = "railconnect-node-group"
      use_name_prefix = true

      capacity_type  = "ON_DEMAND"
      instance_types = var.eks_node_instance_types

      min_size     = var.eks_node_min_size
      max_size     = var.eks_node_max_size
      desired_size = var.eks_node_desired_size

      # Enable auto scaling discovery
      tags = {
        "k8s.io/cluster-autoscaler/${local.cluster_name}" = "owned"
        "k8s.io/cluster-autoscaler/enabled"               = "true"
      }

      # IAM role policies for nodes
      iam_role_additional_policies = {
        AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
        CloudWatchAgentServerPolicy  = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
      }

      # Taints for pod scheduling control
      taints = []

      # Labels for pod selectors
      labels = {
        Environment = "production"
        Workload    = "general"
      }
    }
  }

  # Cluster addons
  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
  }

  # OIDC provider for IRSA (IAM Roles for Service Accounts)
  enable_irsa = true

  tags = local.tags
}

# Security Group for RDS
resource "aws_security_group" "rds" {
  name        = "railconnect-rds-sg"
  description = "Security group for RailConnect RDS PostgreSQL"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [module.eks.node_security_group_id]
    description     = "PostgreSQL from EKS nodes"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.tags
}

# RDS PostgreSQL Database
resource "aws_db_subnet_group" "rds" {
  name       = "railconnect-rds-subnet-group"
  subnet_ids = module.vpc.private_subnets

  tags = local.tags
}

resource "aws_db_instance" "railconnect" {
  identifier            = "railconnect-db"
  allocated_storage    = var.rds_allocated_storage
  storage_type         = "gp3"
  engine               = "postgres"
  engine_version       = var.rds_engine_version
  instance_class       = var.rds_instance_class
  db_name              = var.rds_database_name
  username             = var.rds_username
  password             = var.rds_password
  parameter_group_name = "default.postgres15"
  db_subnet_group_name = aws_db_subnet_group.rds.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  skip_final_snapshot       = false
  final_snapshot_identifier = "railconnect-db-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"

  backup_retention_period = 7
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"

  publicly_accessible = false
  multi_az           = true

  storage_encrypted                   = true
  iam_database_authentication_enabled = true

  tags = local.tags
}

# Security Group for Redis
resource "aws_security_group" "redis" {
  count       = var.enable_redis ? 1 : 0
  name        = "railconnect-redis-sg"
  description = "Security group for RailConnect ElastiCache Redis"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [module.eks.node_security_group_id]
    description     = "Redis from EKS nodes"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.tags
}

# ElastiCache Redis Cluster
resource "aws_elasticache_subnet_group" "redis" {
  count      = var.enable_redis ? 1 : 0
  name       = "railconnect-redis-subnet-group"
  subnet_ids = module.vpc.private_subnets

  tags = local.tags
}

resource "aws_elasticache_cluster" "railconnect" {
  count              = var.enable_redis ? 1 : 0
  cluster_id         = "railconnect-redis"
  engine             = "redis"
  node_type          = var.redis_node_type
  num_cache_nodes    = var.redis_num_cache_nodes
  parameter_group_name = "default.redis7"
  engine_version     = "7.0"
  port               = 6379
  subnet_group_name  = aws_elasticache_subnet_group.redis[0].name
  security_group_ids = [aws_security_group.redis[0].id]

  automatic_failover_enabled = var.redis_num_cache_nodes > 1 ? true : false
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true

  snapshot_retention_limit = 5
  snapshot_window         = "03:00-05:00"

  maintenance_window = "sun:05:00-sun:07:00"
  notification_topic_arn = ""

  log_delivery_configuration {
    destination      = aws_cloudwatch_log_group.redis_slow_log[0].name
    destination_type = "cloudwatch-logs"
    log_format       = "json"
    log_type         = "slow-log"
  }

  tags = local.tags
}

# CloudWatch Log Group for Redis
resource "aws_cloudwatch_log_group" "redis_slow_log" {
  count             = var.enable_redis ? 1 : 0
  name              = "/aws/elasticache/railconnect-redis/slow-log"
  retention_in_days = 7

  tags = local.tags
}

# Outputs
output "eks_cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "eks_cluster_version" {
  description = "Kubernetes version"
  value       = module.eks.cluster_version
}

output "rds_endpoint" {
  description = "RDS endpoint"
  value       = aws_db_instance.railconnect.endpoint
}

output "rds_database_name" {
  description = "RDS database name"
  value       = aws_db_instance.railconnect.db_name
}

output "redis_endpoint" {
  description = "Redis cluster endpoint"
  value       = try(aws_elasticache_cluster.railconnect[0].cache_nodes[0].address, "N/A")
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnets
}
