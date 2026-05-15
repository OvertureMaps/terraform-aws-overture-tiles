# ──────────────────────────────────────────────
# General
# ──────────────────────────────────────────────

variable "name_prefix" {
  description = "Prefix applied to all resource names to avoid collisions across deployments."
  type        = string
  default     = "overture-tiles"
}

# ──────────────────────────────────────────────
# Name overrides — set these to import existing resources without renaming them.
# When null the module derives a name from name_prefix.
# ──────────────────────────────────────────────

variable "cloudwatch_log_group_name" {
  description = "Override for the CloudWatch log group name. When null defaults to /aws/batch/<name_prefix>."
  type        = string
  default     = null
}

variable "job_role_name" {
  description = "Fixed name for the Batch job IAM role. When null a name_prefix is used."
  type        = string
  default     = null
}

variable "job_role_policy_name" {
  description = "Fixed name for the inline S3 write policy on the job role. When null a name_prefix is used."
  type        = string
  default     = null
}

variable "execution_role_name" {
  description = "Fixed name for the ECS task execution IAM role. When null a name_prefix is used."
  type        = string
  default     = null
}

variable "execution_role_policy_name" {
  description = "Fixed name for the inline logs policy on the execution role. When null a name_prefix is used."
  type        = string
  default     = null
}

variable "execution_role_additional_actions" {
  description = "Extra IAM actions to add to the execution role inline policy (e.g. [\"sts:AssumeRole\"])."
  type        = list(string)
  default     = []
}

variable "execution_role_policy_resources" {
  description = "Resource ARNs for the execution role inline policy. Defaults to [\"*\"] when any additional_actions are present; otherwise scoped to the log group."
  type        = list(string)
  default     = null
}

variable "instance_role_name" {
  description = "Fixed name for the EC2 instance IAM role. When null a name_prefix is used."
  type        = string
  default     = null
}

variable "instance_profile_name" {
  description = "Fixed name for the EC2 instance profile. When null a name_prefix is used."
  type        = string
  default     = null
}

variable "security_group_name" {
  description = "Fixed name for the Batch compute environment security group. When null a name_prefix is used."
  type        = string
  default     = null
}

# ──────────────────────────────────────────────
# Scratch bucket — optional extra S3 access for the job role
# ──────────────────────────────────────────────

variable "scratch_bucket_name" {
  description = "Name of a scratch S3 bucket that job containers need read/write access to. When set, an additional inline policy (ListBucket + GetObject/PutObject/PutObjectAcl) is attached to the job role covering both the scratch bucket and the release/tiles bucket."
  type        = string
  default     = null
}

variable "scratch_role_policy_name" {
  description = "Fixed name for the scratch+release readwrite inline policy on the job role. When null a name_prefix is used."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to every resource that supports them."
  type        = map(string)
  default     = {}
}

# ──────────────────────────────────────────────
# S3
# ──────────────────────────────────────────────

variable "create_s3_bucket" {
  description = "Whether to create the tiles S3 bucket. Set to false when the bucket already exists and should not be managed by this module."
  type        = bool
  default     = true
}

variable "bucket_name" {
  description = "Name of the S3 bucket used to store generated PMTiles. Required when create_s3_bucket is true; used in IAM policies when create_s3_bucket is false."
  type        = string
  default     = null

  validation {
    condition     = !var.create_s3_bucket || var.bucket_name != null
    error_message = "bucket_name is required when create_s3_bucket is true."
  }
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

variable "launch_template_name_prefix" {
  description = "Override for the launch template name_prefix. When null defaults to <name_prefix>-."
  type        = string
  default     = null
}

variable "ebs_device_name" {
  description = "Device name for an additional EBS volume attached via the launch template. When null no extra EBS volume is added."
  type        = string
  default     = null
}

variable "ebs_volume_size_gb" {
  description = "Size (GiB) of the extra EBS volume. Only used when ebs_device_name is set."
  type        = number
  default     = 2500
}

variable "ebs_volume_type" {
  description = "EBS volume type for the extra volume. Only used when ebs_device_name is set."
  type        = string
  default     = "gp3"
}

variable "ebs_iops" {
  description = "Provisioned IOPS for the extra EBS volume. Only used when ebs_device_name is set."
  type        = number
  default     = 10000
}

variable "ebs_throughput" {
  description = "Throughput (MB/s) for the extra EBS volume. Only used when ebs_device_name is set."
  type        = number
  default     = 500
}

variable "compute_env_name_prefix" {
  description = "Override for the Batch compute environment name_prefix. When null defaults to <name_prefix>-."
  type        = string
  default     = null
}

variable "service_role_arn" {
  description = "ARN of the IAM service-linked role for AWS Batch. When null the service_role attribute is omitted and AWS uses the default service-linked role."
  type        = string
  default     = null
}
  description = "ECS-optimised AMI family for the ec2_configuration block (e.g. ECS_AL2023). When null the ec2_configuration block is omitted."
  type        = string
  default     = null
}

variable "job_definition_name_overrides" {
  description = "Map of theme name to Batch job definition name. Any theme not listed uses the default <name_prefix>-<theme> name."
  type        = map(string)
  default     = {}
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
    condition     = var.create_vpc || try(length(var.subnet_ids) > 0, false)
    error_message = "subnet_ids must be provided when create_vpc is false."
  }
}
