# Example: complete

A complete, working deployment of the `overturemaps/overture-tiles/aws` module.

Provisions:

- S3 bucket with public access and CORS enabled
- CloudFront distribution (`PriceClass_All`)
- AWS Batch compute environment (`c7gd.8xlarge` on-demand, Graviton3 + NVMe instance store)
- Batch job definitions for all 7 Overture themes
- Managed VPC with public subnets

## Usage

```hcl
module "overture_tiles" {
  source  = "overturemaps/overture-tiles/aws"
  version = "~> 1.0"

  bucket_name = "my-overture-tiles"
}
```

```bash
tofu init
tofu apply -var="bucket_name=my-overture-tiles"
```

## Requirements

| Name      | Version  |
| --------- | -------- |
| OpenTofu  | >= 1.8.0 |
| Terraform | >= 1.8.0 |

## Inputs

| Name          | Description                               | Default                        |
| ------------- | ----------------------------------------- | ------------------------------ |
| `bucket_name` | S3 bucket name for generated PMTiles      | required                       |
| `name_prefix` | Prefix applied to all resource names      | `"overture-tiles"`             |
| `themes`      | Overture themes to create job definitions | all 7 themes                   |
| `tags`        | Tags applied to every resource            | `{ ManagedBy, Project }` map   |
| `region`      | AWS region to deploy into                 | `"us-west-2"`                  |

## Outputs

| Name                    | Description                             |
| ----------------------- | --------------------------------------- |
| `bucket_id`             | Name of the tiles S3 bucket             |
| `cloudfront_domain_name`| CloudFront distribution domain name     |
| `job_queue_arn`         | Batch job queue ARN                     |
| `job_definition_arns`   | Map of theme → Batch job definition ARN |
