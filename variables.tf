# ──────────────────────────────────────────────
# General
# ──────────────────────────────────────────────

variable "name_prefix" {
  description = "Prefix applied to all resource names to avoid collisions across deployments."
  type        = string
  default     = "overture-tiles"
}

# ──────────────────────────────────────────────
# Name overrides — only needed when importing existing resources into state.
# When omitted every name is derived from name_prefix.
# ──────────────────────────────────────────────

variable "name_overrides" {
  description = "Override names and descriptions for resources that already exist in state. All fields are optional; omitted fields cause the module to derive a name from name_prefix."
  type = object({
    cloudwatch_log_group       = optional(string)
    job_role                   = optional(string)
    job_role_description       = optional(string)
    job_role_policy            = optional(string)
    execution_role             = optional(string)
    execution_role_policy      = optional(string)
    instance_role              = optional(string)
    instance_profile           = optional(string)
    security_group             = optional(string)
    security_group_description = optional(string)
    scratch_role_policy        = optional(string)
  })
  default = {}
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

# ──────────────────────────────────────────────
# Scratch bucket — optional extra S3 access for the job role
# ──────────────────────────────────────────────

variable "scratch_bucket_name" {
  description = "Name of a scratch S3 bucket that job containers need read/write access to. When set, an additional inline policy (ListBucket + GetObject/PutObject/PutObjectAcl) is attached to the job role covering both the scratch bucket and the release/tiles bucket."
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
# Launch template
# ──────────────────────────────────────────────

variable "launch_template" {
  description = "Launch template configuration. Set existing_id to reference an externally-managed launch template and skip creation. All other fields configure the module-managed launch template."
  type = object({
    existing_id                = optional(string)
    name_prefix                = optional(string)
    ami_id                     = optional(string)
    configure_instance_storage = optional(bool, true)
    user_data                  = optional(string)
    tag_specifications = optional(list(object({
      resource_type = string
      tags          = map(string)
    })))
    version = optional(string)
  })
  default = {}
}

# ──────────────────────────────────────────────
# EBS volume
# ──────────────────────────────────────────────

variable "ebs_volume" {
  description = "Additional EBS volume to attach via the launch template. When null no extra EBS volume is added."
  type = object({
    device_name = string
    size_gb     = optional(number, 2500)
    type        = optional(string, "gp3")
    iops        = optional(number, 10000)
    throughput  = optional(number, 500)
  })
  default = null
}

# ──────────────────────────────────────────────
# Compute environment
# ──────────────────────────────────────────────

variable "compute_environment" {
  description = "Configuration for the Batch managed compute environment."
  type = object({
    name_prefix      = optional(string)
    instance_types   = optional(list(string), ["c7gd.8xlarge"])
    use_spot         = optional(bool, false)
    max_vcpus        = optional(number, 256)
    service_role_arn = optional(string)
    ec2_image_type   = optional(string)
  })
  default = {}
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
