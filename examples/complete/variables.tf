variable "region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-west-2"
}

variable "bucket_name" {
  description = "S3 bucket name for generated PMTiles."
  type        = string
}

variable "name_prefix" {
  description = "Prefix applied to all resource names."
  type        = string
  default     = "overture-tiles"
}

variable "themes" {
  description = "Overture themes to create Batch job definitions for."
  type        = list(string)
  default     = ["addresses", "admins", "base", "buildings", "divisions", "places", "transportation"]
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default = {
    ManagedBy = "terraform"
    Project   = "overture-tiles"
  }
}
