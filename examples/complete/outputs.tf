output "bucket_id" {
  description = "Name of the tiles S3 bucket."
  value       = module.overture_tiles.bucket_id
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name."
  value       = module.overture_tiles.cloudfront_domain_name
}

output "job_queue_arn" {
  description = "Batch job queue ARN."
  value       = module.overture_tiles.job_queue_arn
}

output "job_definition_arns" {
  description = "Map of theme → Batch job definition ARN."
  value       = module.overture_tiles.job_definition_arns
}
