# ──────────────────────────────────────────────
# General
# ──────────────────────────────────────────────

variable "name_prefix" {
  description = "Prefix applied to all resource names to avoid collisions across deployments."
  type        = string
  default     = "overture-tiles"
}

variable "tags" {
  description = "Tags to apply to every resource that supports them."
  type        = map(string)
  default     = {}
}

# ──────────────────────────────────────────────
# S3
# ──────────────────────────────────────────────

variable "bucket_name" {
  description = "Name of the S3 bucket used to store generated PMTiles."
  type        = string
}

variable "public_access_enabled" {
  description = "Whether to disable S3 Block Public Access and add a public-read bucket policy. Set to false when access should be restricted to CloudFront OAC only."
  type        = bool
  default     = true
}

variable "cors_allowed_origins" {
  description = "List of origins to allow in the S3 CORS rule for GET requests."
  type        = list(string)
  default     = ["*"]
}

# ──────────────────────────────────────────────
# CloudFront
# ──────────────────────────────────────────────

variable "create_cloudfront_distribution" {
  description = "Whether to create a CloudFront distribution backed by the tiles S3 bucket."
  type        = bool
  default     = true
}

variable "cloudfront_price_class" {
  description = "CloudFront price class controlling which edge locations serve content."
  type        = string
  default     = "PriceClass_All"

  validation {
    condition     = contains(["PriceClass_100", "PriceClass_200", "PriceClass_All"], var.cloudfront_price_class)
    error_message = "cloudfront_price_class must be one of PriceClass_100, PriceClass_200, or PriceClass_All."
  }
}

# ──────────────────────────────────────────────
# Container / Batch jobs
# ──────────────────────────────────────────────

variable "container_image" {
  description = "Container image used by every Batch job definition."
  type        = string
  default     = "ghcr.io/overturemaps/overture-tiles:latest"
}

variable "themes" {
  description = "Overture themes for which to create individual Batch job definitions."
  type        = list(string)
  default     = ["addresses", "admins", "base", "buildings", "divisions", "places", "transportation"]

  validation {
    condition = alltrue([
      for t in var.themes :
      contains(["addresses", "admins", "base", "buildings", "divisions", "places", "transportation"], t)
    ])
    error_message = "Each theme must be one of: addresses, admins, base, buildings, divisions, places, transportation."
  }
}

variable "job_memory_gib" {
  description = "Memory (GiB) reserved for each Batch container."
  type        = number
  default     = 60
}

variable "job_vcpus" {
  description = "vCPUs reserved for each Batch container."
  type        = number
  default     = 30
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention period (days) for Batch job output."
  type        = number
  default     = 30
}

# ──────────────────────────────────────────────
# Compute environment
# ──────────────────────────────────────────────

variable "instance_types" {
  description = "EC2 instance types for the Batch compute environment. Defaults to c7gd.8xlarge (Graviton3 + NVMe instance store)."
  type        = list(string)
  default     = ["c7gd.8xlarge"]
}

variable "use_spot" {
  description = "Whether to use EC2 Spot instances. When true the allocation strategy switches to SPOT_CAPACITY_OPTIMIZED."
  type        = bool
  default     = false
}

variable "max_vcpus" {
  description = "Maximum total vCPUs across all instances in the compute environment."
  type        = number
  default     = 256
}

variable "ami_id" {
  description = "Custom AMI ID for the Batch EC2 launch template. When null the module looks up the latest ECS-optimized Amazon Linux 2023 ARM64 AMI via SSM."
  type        = string
  default     = null
}

variable "configure_instance_storage" {
  description = "Whether to format and mount NVMe instance-store volumes as the Docker data root on launch. Recommended for c7gd and other NVMe-backed instance families."
  type        = bool
  default     = true
}

# ──────────────────────────────────────────────
# Networking
# ──────────────────────────────────────────────

variable "create_vpc" {
  description = "Whether to create a dedicated VPC for the Batch compute environment. Set to false to supply an existing vpc_id and subnet_ids."
  type        = bool
  default     = true
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC when create_vpc is true."
  type        = string
  default     = "10.0.0.0/16"
}

variable "vpc_id" {
  description = "ID of an existing VPC. Required when create_vpc is false."
  type        = string
  default     = null
}

variable "subnet_ids" {
  description = "IDs of existing subnets (must have internet access) for the Batch compute environment. Required when create_vpc is false."
  type        = list(string)
  default     = null

  validation {
    condition     = var.create_vpc || (var.subnet_ids != null && length(var.subnet_ids) > 0)
    error_message = "subnet_ids must be provided when create_vpc is false."
  }
}
