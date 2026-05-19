# terraform-aws-overture-tiles

[![CI](https://github.com/OvertureMaps/terraform-aws-overture-tiles/actions/workflows/ci.yml/badge.svg)](https://github.com/OvertureMaps/terraform-aws-overture-tiles/actions/workflows/ci.yml)
[![OpenTofu Registry](https://img.shields.io/badge/OpenTofu-overturemaps%2Foverture--tiles%2Faws-purple?logo=opentofu)](https://search.opentofu.org/module/overturemaps/overture-tiles/aws/latest)
[![Terraform Registry](https://img.shields.io/badge/Terraform-Registry-7B42BC?logo=terraform)](https://registry.terraform.io/modules/OvertureMaps/overture-tiles/aws/latest)
[![License](https://img.shields.io/github/license/OvertureMaps/terraform-aws-overture-tiles)](LICENSE)

Terraform module that provisions the AWS infrastructure required to generate and serve [Overture Maps](https://overturemaps.org) data as [PMTiles](https://protomaps.com/).

## What this module creates

| Resource                      | Purpose                                                                                                      |
| ----------------------------- | ------------------------------------------------------------------------------------------------------------ |
| S3 bucket                     | Stores generated PMTiles files                                                                               |
| CloudFront distribution       | Serves tiles globally (optional)                                                                             |
| AWS Batch compute environment | Runs tile generation jobs on EC2 (Graviton3 + NVMe instance store by default)                                |
| Batch job queue               | Queues tile generation work                                                                                  |
| Batch job definitions         | One per Overture theme (`addresses`, `admins`, `base`, `buildings`, `divisions`, `places`, `transportation`) |
| IAM roles                     | Job role (S3 write) and ECS execution role (image pull, CloudWatch Logs)                                     |
| CloudWatch log group          | Captures Batch job output                                                                                    |
| VPC + subnets                 | Optional — created when `create_vpc = true`                                                                  |

## Usage

```hcl
module "overture_tiles" {
  source  = "overturemaps/overture-tiles/aws"
  version = "~> 1.0"

  bucket_name = "my-overture-tiles"

  # Optional — all fields have defaults
  name_prefix                    = "overture-tiles"
  create_cloudfront_distribution = true
  cloudfront_price_class         = "PriceClass_All"
  themes                         = ["addresses", "admins", "base", "buildings", "divisions", "places", "transportation"]
  container_image                = "ghcr.io/overturemaps/overture-tiles:latest"
  job_memory_gib                 = 60
  job_vcpus                      = 30
  create_vpc                     = true
  tags                           = {}

  compute_environment = {
    instance_types = ["c7gd.8xlarge"]
    use_spot       = false
    max_vcpus      = 256
  }

  launch_template = {
    configure_instance_storage = true
  }
}
```

See [`examples/complete`](examples/complete) for a full working example.

## Compatibility

The module HCL is compatible with both **OpenTofu** (≥ 1.8) and **Terraform** (≥ 1.8). CI validates against OpenTofu; if you use Terraform, run `terraform init` to regenerate the lock file for your registry.

## Requirements

| Name               | Version       |
| ------------------ | ------------- |
| OpenTofu           | >= 1.8.0      |
| Terraform          | >= 1.8.0      |
| AWS provider       | >= 5.0, < 7.0 |
| cloudinit provider | >= 2.0        |

## Inputs

### Scalar inputs

| Name                             | Description                                                                   | Type           | Default                                        | Required                             |
| -------------------------------- | ----------------------------------------------------------------------------- | -------------- | ---------------------------------------------- | ------------------------------------ |
| `bucket_name`                    | S3 bucket name for generated PMTiles                                          | `string`       | `null`                                         | yes (when `create_s3_bucket = true`) |
| `name_prefix`                    | Prefix applied to all resource names                                          | `string`       | `"overture-tiles"`                             | no                                   |
| `tags`                           | Tags applied to every resource                                                | `map(string)`  | `{}`                                           | no                                   |
| `create_s3_bucket`               | Create the tiles S3 bucket                                                    | `bool`         | `true`                                         | no                                   |
| `public_access_enabled`          | Disable S3 Block Public Access and add public-read policy                     | `bool`         | `true`                                         | no                                   |
| `cors_allowed_origins`           | Origins allowed in the S3 CORS rule                                           | `list(string)` | `["*"]`                                        | no                                   |
| `create_cloudfront_distribution` | Create a CloudFront distribution backed by the S3 bucket                      | `bool`         | `true`                                         | no                                   |
| `cloudfront_price_class`         | CloudFront price class (`PriceClass_100`, `PriceClass_200`, `PriceClass_All`) | `string`       | `"PriceClass_All"`                             | no                                   |
| `container_image`                | Container image used by every Batch job definition                            | `string`       | `"ghcr.io/overturemaps/overture-tiles:latest"` | no                                   |
| `themes`                         | Overture themes for which to create Batch job definitions                     | `list(string)` | all 7 themes                                   | no                                   |
| `job_definition_name_overrides`  | Map of theme → job definition name override                                   | `map(string)`  | `{}`                                           | no                                   |
| `job_memory_gib`                 | Memory (GiB) allocated to each Batch job                                      | `number`       | `60`                                           | no                                   |
| `job_vcpus`                      | vCPUs allocated to each Batch job                                             | `number`       | `30`                                           | no                                   |
| `log_retention_days`             | CloudWatch log retention in days                                              | `number`       | `30`                                           | no                                   |
| `create_vpc`                     | Create a minimal VPC for the Batch compute environment                        | `bool`         | `true`                                         | no                                   |
| `vpc_cidr`                       | CIDR block for the managed VPC                                                | `string`       | `"10.0.0.0/16"`                                | no                                   |
| `vpc_id`                         | Existing VPC ID (required when `create_vpc = false`)                          | `string`       | `null`                                         | conditional                          |
| `subnet_ids`                     | Existing subnet IDs (required when `create_vpc = false`)                      | `list(string)` | `null`                                         | conditional                          |

### `name_overrides` object

Override names for resources that already exist in state. All fields are optional. **`security_group_description` is immutable in AWS — it must match the existing value or the security group (and compute environment) will be replaced.**

| Field                        | Description                                  |
| ---------------------------- | -------------------------------------------- |
| `cloudwatch_log_group`       | CloudWatch log group name                    |
| `job_role`                   | Batch job IAM role name                      |
| `job_role_policy`            | Batch job inline policy name                 |
| `execution_role`             | ECS task execution role name                 |
| `execution_role_policy`      | Execution role inline policy name            |
| `instance_role`              | EC2 instance IAM role name                   |
| `instance_profile`           | EC2 instance profile name                    |
| `security_group`             | Batch security group name                    |
| `security_group_description` | Batch security group description (immutable) |

### `compute_environment` object

| Field              | Description                                  | Default            |
| ------------------ | -------------------------------------------- | ------------------ |
| `instance_types`   | EC2 instance types                           | `["c7gd.8xlarge"]` |
| `use_spot`         | Use Spot instances                           | `false`            |
| `max_vcpus`        | Maximum vCPUs                                | `256`              |
| `service_role_arn` | Batch service-linked role ARN                | `null`             |
| `ec2_image_type`   | ECS-optimised AMI family (e.g. `ECS_AL2023`) | `null`             |
| `name_prefix`      | Compute environment `name_prefix` override   | `null`             |

### `launch_template` object

| Field                | Description                                                                                 | Default                      |
| -------------------- | ------------------------------------------------------------------------------------------- | ---------------------------- |
| `existing_id`        | ID of an externally-managed launch template (skips creation)                                | `null`                       |
| `name_prefix`        | Launch template `name_prefix` override                                                      | `null`                       |
| `ami_id`             | Custom ECS-optimised AMI ID                                                                 | `null` (latest ARM64 AL2023) |
| `user_data`          | Plain shell script — automatically wrapped in MIME multipart format (required by AWS Batch) | `null`                       |
| `tag_specifications` | List of `{ resource_type, tags }` tag specification objects                                 | `null`                       |
| `version`            | Launch template version to use in the compute environment                                   | `null`                       |

### `ebs_volume` object

When set, attaches an additional EBS volume via the launch template.

| Field         | Description                    | Default  |
| ------------- | ------------------------------ | -------- |
| `device_name` | Device name (e.g. `/dev/xvdf`) | required |
| `size_gb`     | Volume size in GiB             | `2500`   |
| `type`        | EBS volume type                | `"gp3"`  |
| `iops`        | Provisioned IOPS               | `10000`  |
| `throughput`  | Throughput in MB/s             | `500`    |

## Outputs

| Name                          | Description                                              |
| ----------------------------- | -------------------------------------------------------- |
| `bucket_id`                   | S3 bucket name                                           |
| `bucket_arn`                  | S3 bucket ARN                                            |
| `bucket_regional_domain_name` | S3 bucket regional domain name                           |
| `cloudfront_distribution_id`  | CloudFront distribution ID (null if disabled)            |
| `cloudfront_domain_name`      | CloudFront distribution domain name (null if disabled)   |
| `cloudfront_distribution_arn` | CloudFront distribution ARN (null if disabled)           |
| `job_queue_arn`               | Batch job queue ARN                                      |
| `job_definition_arns`         | Map of theme → Batch job definition ARN                  |
| `compute_environment_arn`     | Batch compute environment ARN                            |
| `job_role_arn`                | ARN of the IAM role assumed by Batch task containers     |
| `job_role_name`               | Name of the IAM role assumed by Batch task containers    |
| `execution_role_arn`          | ARN of the IAM role used by the ECS agent                |
| `execution_role_name`         | Name of the IAM role used by the ECS agent               |
| `log_group_name`              | CloudWatch Logs group name for Batch job output          |
| `vpc_id`                      | ID of the VPC used by the Batch compute environment      |
| `subnet_ids`                  | IDs of the subnets used by the Batch compute environment |
