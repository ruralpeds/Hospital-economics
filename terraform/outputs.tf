output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = module.vpc.private_subnets
}

output "eks_cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "Endpoint for the EKS cluster API server"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_certificate_authority" {
  description = "Base64-encoded certificate data for the EKS cluster"
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "rds_endpoint" {
  description = "Endpoint of the RDS PostgreSQL instance"
  value       = aws_db_instance.main.endpoint
}

output "rds_port" {
  description = "Port of the RDS PostgreSQL instance"
  value       = aws_db_instance.main.port
}

output "redis_endpoint" {
  description = "Primary endpoint of the ElastiCache Redis replication group"
  value       = aws_elasticache_replication_group.main.primary_endpoint_address
}

output "redis_port" {
  description = "Port of the ElastiCache Redis cluster"
  value       = aws_elasticache_replication_group.main.port
}

output "kms_key_arn" {
  description = "ARN of the KMS key used for encryption"
  value       = aws_kms_key.main.arn
}

output "kms_key_id" {
  description = "ID of the KMS key used for encryption"
  value       = aws_kms_key.main.key_id
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket for backups"
  value       = aws_s3_bucket.backups.id
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket for backups"
  value       = aws_s3_bucket.backups.arn
}

output "cloudwatch_log_group" {
  description = "Name of the CloudWatch log group for the application"
  value       = aws_cloudwatch_log_group.app.name
}
