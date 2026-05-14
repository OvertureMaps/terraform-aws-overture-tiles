module "overture_tiles" {
  source = "../.."

  name_prefix = var.name_prefix
  bucket_name = var.bucket_name
  themes      = var.themes
  tags        = var.tags

  # S3 – publicly readable so tiles can be served directly or via CloudFront
  public_access_enabled = true
  cors_allowed_origins  = ["*"]

  # CloudFront in front of the bucket
  create_cloudfront_distribution = true
  cloudfront_price_class         = "PriceClass_All"

  # Batch jobs – defaults match the overture-tiles CDK stack
  container_image = "ghcr.io/overturemaps/overture-tiles:latest"
  job_memory_gib  = 60
  job_vcpus       = 30

  # Compute environment – c7gd.8xlarge: Graviton3 + 1.9 TB NVMe instance store
  instance_types             = ["c7gd.8xlarge"]
  use_spot                   = false
  max_vcpus                  = 256
  configure_instance_storage = true

  # Network – let the module create a minimal VPC
  create_vpc = true
}
