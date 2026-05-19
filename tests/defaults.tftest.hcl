# tests/defaults.tftest.hcl
#
# Validates the plan produced by the module's default configuration without
# making any real AWS API calls. Requires OpenTofu >= 1.8 or Terraform >= 1.8.

mock_provider "aws" {
  mock_data "aws_availability_zones" {
    defaults = {
      names = ["us-east-1a", "us-east-1b", "us-east-1c"]
    }
  }

  mock_data "aws_ssm_parameter" {
    defaults = {
      value = "ami-0123456789abcdef0"
    }
  }

  mock_data "aws_region" {
    defaults = {
      id = "us-east-1"
    }
  }

  # Provide a valid ARN for the instance profile so the Batch compute
  # environment's instance_role ARN validation passes during plan.
  mock_resource "aws_iam_instance_profile" {
    defaults = {
      arn = "arn:aws:iam::123456789012:instance-profile/mock-profile"
    }
  }

  # Provide valid ARNs for the CloudFront distribution so the S3 bucket
  # policy condition and output references resolve correctly.
  mock_resource "aws_cloudfront_distribution" {
    defaults = {
      arn         = "arn:aws:cloudfront::123456789012:distribution/MOCKDISTID"
      domain_name = "mock.cloudfront.net"
    }
  }

  mock_resource "aws_cloudwatch_log_group" {
    defaults = {
      arn = "arn:aws:logs:us-east-1:123456789012:log-group:/aws/batch/overture-tiles"
    }
  }

  mock_resource "aws_launch_template" {
    defaults = {
      id = "lt-0mock1234567890ab"
    }
  }

  mock_resource "aws_batch_compute_environment" {
    defaults = {
      arn = "arn:aws:batch:us-east-1:123456789012:compute-environment/mock-ce"
    }
  }

  mock_resource "aws_s3_bucket" {
    defaults = {
      arn                         = "arn:aws:s3:::test-overture-tiles-bucket"
      bucket_regional_domain_name = "test-overture-tiles-bucket.s3.us-east-1.amazonaws.com"
    }
  }

  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

variables {
  bucket_name = "test-overture-tiles-bucket"
}

# ──────────────────────────────────────────────
# run: default plan
# ──────────────────────────────────────────────

run "default_config_plan" {
  command = plan

  # S3 bucket name is propagated correctly.
  assert {
    condition     = aws_s3_bucket.tiles[0].bucket == "test-overture-tiles-bucket"
    error_message = "Bucket name should match var.bucket_name."
  }

  # Public access block is disabled (all four attributes = false).
  assert {
    condition     = aws_s3_bucket_public_access_block.tiles[0].block_public_acls == false
    error_message = "block_public_acls should be false when public_access_enabled is true."
  }

  # CORS is configured on the bucket.
  assert {
    condition     = length(aws_s3_bucket_cors_configuration.tiles[0].cors_rule) == 1
    error_message = "Default config should have exactly one CORS rule."
  }

  # CloudFront distribution is created by default.
  assert {
    condition     = length(aws_cloudfront_distribution.tiles) == 1
    error_message = "CloudFront distribution should be created by default."
  }

  # OAC is created alongside the distribution.
  assert {
    condition     = length(aws_cloudfront_origin_access_control.tiles) == 1
    error_message = "CloudFront OAC should be created when create_cloudfront_distribution is true."
  }

  # Seven job definitions, one per default theme.
  assert {
    condition     = length(aws_batch_job_definition.tiles) == 7
    error_message = "Should create exactly 7 Batch job definitions (one per default theme)."
  }

  # Job queue references the compute environment.
  assert {
    condition     = length(aws_batch_job_queue.tiles.compute_environment_order) == 1
    error_message = "Job queue should reference exactly one compute environment."
  }

  # VPC is created by default.
  assert {
    condition     = length(aws_vpc.batch) == 1
    error_message = "A VPC should be created when create_vpc is true (default)."
  }

  # One public subnet is created.
  assert {
    condition     = length(aws_subnet.public) == 1
    error_message = "One public subnet should be created."
  }

  # Internet gateway is attached.
  assert {
    condition     = length(aws_internet_gateway.batch) == 1
    error_message = "An internet gateway should be created with the managed VPC."
  }

  # Compute environment uses EC2 (not Spot) by default.
  assert {
    condition     = aws_batch_compute_environment.tiles.compute_resources[0].type == "EC2"
    error_message = "Default compute type should be EC2."
  }

  # Allocation strategy matches CDK default.
  assert {
    condition     = aws_batch_compute_environment.tiles.compute_resources[0].allocation_strategy == "BEST_FIT"
    error_message = "Default allocation strategy should be BEST_FIT."
  }

  # User data is null when no user_data is provided.
  assert {
    condition     = aws_launch_template.batch[0].user_data == null
    error_message = "User data should be null when no user_data is provided."
  }

  # Log group is created.
  assert {
    condition     = aws_cloudwatch_log_group.batch.name == "/aws/batch/overture-tiles"
    error_message = "Log group name should be /aws/batch/<name_prefix>."
  }

  # Three IAM roles created (job, execution, ecs_instance).
  assert {
    condition     = aws_iam_role.job.name_prefix == "overture-tiles-job-"
    error_message = "Job role name_prefix should include the name_prefix variable."
  }
}
