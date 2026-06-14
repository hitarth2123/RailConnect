terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
  }

  backend "s3" {
    bucket         = "railconnect-tfstate-ACCOUNT-ID"
    key            = "railconnect/production/terraform.tfstate"
    region         = "ap-south-1"
    encrypt        = true
    dynamodb_table = "railconnect-tf-lock"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project      = "railconnect"
      Environment  = "production"
      ManagedBy    = "terraform"
      CreatedDate  = timestamp()
    }
  }
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name
}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  cluster_name = "railconnect-prod"
  tags = {
    Project     = "railconnect"
    Environment = "production"
    ManagedBy   = "terraform"
  }
}
