# terraform-aws-overture-tiles

Terraform module that provisions the AWS infrastructure required to generate and serve [Overture Maps](https://overturemaps.org) PMTiles.

## What this module creates

| Resource | Purpose |
|---|---|
| S3 bucket | Stores generated PMTiles files |
| CloudFront distribution | Serves tiles globally (optional) |
| AWS Batch compute environment | Runs tile generation jobs on EC2 (Graviton3 + NVMe instance store by default) |
| Batch job queue | Queues tile generation work |
| Batch job definitions | One per Overture theme (`addresses`, `admins`, `base`, `buildings`, `divisions`, `places`, `transportation`) |
| IAM roles | Job role (S3 write) and ECS execution role (image pull, CloudWatch Logs) |
| CloudWatch log group | Captures Batch job output |
| VPC + subnets | Optional — created when `create_vpc = true` |

## Usage

```hcl
module "overture_tiles" {
  source = "github.com/OvertureMaps/terraform-aws-overture-tiles"

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

| Name | Version |
|---|---|
| OpenTofu | >= 1.8.0 |
| Terraform | >= 1.8.0 |
| AWS provider | >= 5.0, < 7.0 |

## Inputs

| Name | Description | Type | Default | Required |
|---|---|---|---|---|
| `bucket_name` | S3 bucket name for generated PMTiles (required when `create_s3_bucket = true`; used in IAM policies when false) | `string` | `null` | conditional |
| `name_prefix` | Prefix applied to all resource names | `string` | `"overture-tiles"` | no |
| `tags` | Tags applied to every resource | `map(string)` | `{}` | no |
| `create_s3_bucket` | Create the tiles S3 bucket | `bool` | `true` | no |
| `public_access_enabled` | Disable S3 Block Public Access and add public-read policy | `bool` | `true` | no |
| `cors_allowed_origins` | Origins allowed in the S3 CORS rule | `list(string)` | `["*"]` | no |
| `create_cloudfront_distribution` | Create a CloudFront distribution backed by the S3 bucket | `bool` | `true` | no |
| `cloudfront_price_class` | CloudFront price class | `string` | `"PriceClass_All"` | no |
| `container_image` | Container image used by every Batch job definition | `string` | `"ghcr.io/overturemaps/overture-tiles:latest"` | no |
| `themes` | Overture themes for which to create Batch job definitions | `list(string)` | all 7 themes | no |
| `job_definition_name_overrides` | Map of theme → job definition name override | `map(string)` | `{}` | no |
| `instance_types` | EC2 instance types for the Batch compute environment | `list(string)` | `["c7gd.8xlarge"]` | no |
| `job_memory_gib` | Memory (GiB) allocated to each Batch job | `number` | `60` | no |
| `job_vcpus` | vCPUs allocated to each Batch job | `number` | `30` | no |
| `max_vcpus` | Maximum vCPUs for the Batch compute environment | `number` | `256` | no |
| `use_spot` | Use Spot instances for the compute environment | `bool` | `false` | no |
| `configure_instance_storage` | Format and mount NVMe instance store as Docker data root | `bool` | `true` | no |
| `ami_id` | Custom ECS-optimised AMI ID (defaults to latest ARM64 Amazon Linux 2023) | `string` | `null` | no |
| `service_role_arn` | ARN of the IAM service-linked role for Batch; omitted when null | `string` | `null` | no |
| `ec2_image_type` | ECS-optimised AMI family for `ec2_configuration` (e.g. `ECS_AL2023`); omitted when null | `string` | `null` | no |
| `launch_template_name_prefix` | Override for the launch template `name_prefix`; defaults to `<name_prefix>-` | `string` | `null` | no |
| `ebs_device_name` | Device name for an extra EBS volume on the launch template; no volume when null | `string` | `null` | no |
| `ebs_volume_size_gb` | Size (GiB) of the extra EBS volume | `number` | `2500` | no |
| `ebs_volume_type` | EBS volume type for the extra volume | `string` | `"gp3"` | no |
| `ebs_iops` | Provisioned IOPS for the extra EBS volume | `number` | `10000` | no |
| `ebs_throughput` | Throughput (MB/s) for the extra EBS volume | `number` | `500` | no |
| `scratch_bucket_name` | Name of a scratch S3 bucket; when set adds a readwrite inline policy to the job role | `string` | `null` | no |
| `create_vpc` | Create a minimal VPC for the Batch compute environment | `bool` | `false` | no |
| `log_retention_days` | CloudWatch log retention in days | `number` | `30` | no |
| `cloudwatch_log_group_name` | Override for the CloudWatch log group name; defaults to `/aws/batch/<name_prefix>` | `string` | `null` | no |
| `job_role_name` | Fixed name for the Batch job IAM role; uses `name_prefix` when null | `string` | `null` | no |
| `job_role_policy_name` | Fixed name for the S3 write inline policy on the job role | `string` | `null` | no |
| `scratch_role_policy_name` | Fixed name for the scratch readwrite inline policy on the job role | `string` | `null` | no |
| `execution_role_name` | Fixed name for the ECS task execution IAM role | `string` | `null` | no |
| `execution_role_policy_name` | Fixed name for the logs inline policy on the execution role | `string` | `null` | no |
| `execution_role_additional_actions` | Extra IAM actions for the execution role inline policy | `list(string)` | `[]` | no |
| `execution_role_policy_resources` | Resource ARNs for the execution role inline policy | `list(string)` | `null` | no |
| `instance_role_name` | Fixed name for the EC2 instance IAM role | `string` | `null` | no |
| `instance_profile_name` | Fixed name for the EC2 instance profile | `string` | `null` | no |
| `security_group_name` | Fixed name for the Batch security group | `string` | `null` | no |

## Outputs

| Name | Description |
|---|---|
| `bucket_id` | S3 bucket name |
| `bucket_arn` | S3 bucket ARN |
| `bucket_regional_domain_name` | S3 bucket regional domain name |
| `cloudfront_distribution_id` | CloudFront distribution ID (null if disabled) |
| `cloudfront_domain_name` | CloudFront distribution domain name (null if disabled) |
| `cloudfront_distribution_arn` | CloudFront distribution ARN (null if disabled) |
| `job_queue_arn` | Batch job queue ARN |
| `job_definition_arns` | Map of theme → Batch job definition ARN |
| `compute_environment_arn` | Batch compute environment ARN |
| `job_role_arn` | IAM role ARN assumed by Batch task containers |
| `execution_role_arn` | IAM role ARN used by the ECS agent |
| `log_group_name` | CloudWatch Logs group name for Batch job output |

## Maintainers

This repository uses `MAINTAINERS.md` files to track ownership for [LFX Insights](https://insights.linuxfoundation.org/docs/introduction/maintainers/) ingestion. LFX scans the full repository tree, so these files can live anywhere.

To add a `MAINTAINERS.md` for a module or package, create it in the relevant directory using this format:

```markdown
# MAINTAINERS

| Name     | GitHub Username | Role            | Affiliation |
| -------- | --------------- | --------------- | ----------- |
| Jane Doe | @janedoe        | Lead Maintainer | Org         |
```

## License

[Apache 2.0](LICENSE)
