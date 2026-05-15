output "bucket_id" {
  description = "Name (ID) of the tiles S3 bucket."
  value       = var.create_s3_bucket ? aws_s3_bucket.tiles[0].id : var.bucket_name
}

output "bucket_arn" {
  description = "ARN of the tiles S3 bucket."
  value       = local.tiles_bucket_arn
}

output "bucket_regional_domain_name" {
  description = "Regional domain name of the tiles S3 bucket."
  value       = var.create_s3_bucket ? aws_s3_bucket.tiles[0].bucket_regional_domain_name : null
}

output "cloudfront_distribution_id" {
  description = "ID of the CloudFront distribution. Null when create_cloudfront_distribution is false."
  value       = try(aws_cloudfront_distribution.tiles[0].id, null)
}

output "cloudfront_domain_name" {
  description = "Domain name of the CloudFront distribution. Null when create_cloudfront_distribution is false."
  value       = try(aws_cloudfront_distribution.tiles[0].domain_name, null)
}

output "cloudfront_distribution_arn" {
  description = "ARN of the CloudFront distribution. Null when create_cloudfront_distribution is false."
  value       = try(aws_cloudfront_distribution.tiles[0].arn, null)
}

output "job_queue_arn" {
  description = "ARN of the Batch job queue."
  value       = aws_batch_job_queue.tiles.arn
}

output "job_definition_arns" {
  description = "Map of theme name to Batch job definition ARN."
  value       = { for k, v in aws_batch_job_definition.tiles : k => v.arn }
}

output "compute_environment_arn" {
  description = "ARN of the Batch managed compute environment."
  value       = aws_batch_compute_environment.tiles.arn
}

output "job_role_arn" {
  description = "ARN of the IAM role assumed by Batch task containers (used for S3 write access)."
  value       = aws_iam_role.job.arn
}

output "job_role_name" {
  description = "Name of the IAM role assumed by Batch task containers."
  value       = aws_iam_role.job.name
}

output "execution_role_arn" {
  description = "ARN of the IAM role used by the ECS agent to pull images and write logs."
  value       = aws_iam_role.execution.arn
}

output "execution_role_name" {
  description = "Name of the IAM role used by the ECS agent to pull images and write logs."
  value       = aws_iam_role.execution.name
}

output "log_group_name" {
  description = "CloudWatch Logs group name for Batch job output."
  value       = aws_cloudwatch_log_group.batch.name
}

output "vpc_id" {
  description = "ID of the VPC used by the Batch compute environment."
  value       = local.vpc_id
}

output "subnet_ids" {
  description = "IDs of the subnets used by the Batch compute environment."
  value       = local.subnet_ids
}
