# tests/custom_config.tftest.hcl
#
# Validates non-default configurations: disabled CloudFront, Spot, existing
# VPC, subset of themes, and custom name_prefix. Requires OpenTofu >= 1.8 or Terraform >= 1.8.

mock_provider "aws" {
  mock_data "aws_availability_zones" {
    defaults = {
      names = ["eu-west-1a", "eu-west-1b"]
    }
  }

  mock_data "aws_ssm_parameter" {
    defaults = {
      value = "ami-0fedcba9876543210"
    }
  }

  mock_data "aws_region" {
    defaults = {
      id = "eu-west-1"
    }
  }

  mock_resource "aws_iam_instance_profile" {
    defaults = {
      arn = "arn:aws:iam::123456789012:instance-profile/mock-profile"
    }
  }

  mock_resource "aws_cloudfront_distribution" {
    defaults = {
      arn         = "arn:aws:cloudfront::123456789012:distribution/MOCKDISTID"
      domain_name = "mock.cloudfront.net"
    }
  }

  mock_resource "aws_cloudwatch_log_group" {
    defaults = {
      arn = "arn:aws:logs:eu-west-1:123456789012:log-group:/aws/batch/overture-tiles"
    }
  }

  mock_resource "aws_launch_template" {
    defaults = {
      id = "lt-0mock1234567890ab"
    }
  }

  mock_resource "aws_batch_compute_environment" {
    defaults = {
      arn = "arn:aws:batch:eu-west-1:123456789012:compute-environment/mock-ce"
    }
  }

  mock_resource "aws_s3_bucket" {
    defaults = {
      arn                         = "arn:aws:s3:::mock-tiles-bucket"
      bucket_regional_domain_name = "mock-tiles-bucket.s3.eu-west-1.amazonaws.com"
    }
  }

  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

# ──────────────────────────────────────────────
# run: CloudFront disabled
# ──────────────────────────────────────────────

run "no_cloudfront" {
  command = plan

  variables {
    bucket_name                    = "no-cf-tiles-bucket"
    create_cloudfront_distribution = false
  }

  assert {
    condition     = length(aws_cloudfront_distribution.tiles) == 0
    error_message = "No CloudFront distribution should be created when create_cloudfront_distribution is false."
  }

  assert {
    condition     = length(aws_cloudfront_origin_access_control.tiles) == 0
    error_message = "No OAC should be created when create_cloudfront_distribution is false."
  }
}

# ──────────────────────────────────────────────
# run: Spot instances
# ──────────────────────────────────────────────

run "spot_compute" {
  command = plan

  variables {
    bucket_name         = "spot-tiles-bucket"
    compute_environment = { use_spot = true }
  }

  assert {
    condition     = aws_batch_compute_environment.tiles.compute_resources[0].type == "SPOT"
    error_message = "Compute type should be SPOT when use_spot is true."
  }

  assert {
    condition     = aws_batch_compute_environment.tiles.compute_resources[0].allocation_strategy == "SPOT_CAPACITY_OPTIMIZED"
    error_message = "Spot allocation strategy should be SPOT_CAPACITY_OPTIMIZED."
  }
}

# ──────────────────────────────────────────────
# run: subset of themes
# ──────────────────────────────────────────────

run "subset_themes" {
  command = plan

  variables {
    bucket_name = "subset-tiles-bucket"
    themes      = ["base", "buildings", "places"]
  }

  assert {
    condition     = length(aws_batch_job_definition.tiles) == 3
    error_message = "Should create exactly 3 Batch job definitions for 3 themes."
  }

  assert {
    condition     = contains(keys(aws_batch_job_definition.tiles), "base")
    error_message = "Job definition for 'base' theme should exist."
  }

  assert {
    condition     = contains(keys(aws_batch_job_definition.tiles), "buildings")
    error_message = "Job definition for 'buildings' theme should exist."
  }

  assert {
    condition     = contains(keys(aws_batch_job_definition.tiles), "places")
    error_message = "Job definition for 'places' theme should exist."
  }
}

# ──────────────────────────────────────────────
# run: existing VPC (no new network resources)
# ──────────────────────────────────────────────

run "existing_vpc" {
  command = plan

  variables {
    bucket_name = "existing-vpc-tiles-bucket"
    create_vpc  = false
    vpc_id      = "vpc-0123456789abcdef0"
    subnet_ids  = ["subnet-0123456789abcdef0", "subnet-fedcba9876543210f"]
  }

  assert {
    condition     = length(aws_vpc.batch) == 0
    error_message = "No VPC should be created when create_vpc is false."
  }

  assert {
    condition     = length(aws_internet_gateway.batch) == 0
    error_message = "No internet gateway should be created when create_vpc is false."
  }

  assert {
    condition     = length(aws_subnet.public) == 0
    error_message = "No subnet should be created when create_vpc is false."
  }
}

# ──────────────────────────────────────────────
# run: custom name_prefix propagates to all key resources
# ──────────────────────────────────────────────

run "custom_name_prefix" {
  command = plan

  variables {
    bucket_name = "custom-prefix-tiles"
    name_prefix = "my-tiles"
  }

  assert {
    condition     = aws_batch_job_queue.tiles.name == "my-tiles-queue"
    error_message = "Job queue name should use the custom name_prefix."
  }

  assert {
    condition     = aws_cloudwatch_log_group.batch.name == "/aws/batch/my-tiles"
    error_message = "Log group name should use the custom name_prefix."
  }

  assert {
    condition     = aws_iam_role.job.name_prefix == "my-tiles-job-"
    error_message = "Job role name_prefix should use the custom name_prefix."
  }
}

# ──────────────────────────────────────────────
# run: disable instance storage user data
# ──────────────────────────────────────────────

run "no_instance_storage" {
  command = plan

  variables {
    bucket_name     = "no-nvme-tiles-bucket"
    launch_template = { configure_instance_storage = false }
  }

  assert {
    condition     = aws_launch_template.batch[0].user_data == null
    error_message = "User data should be null when configure_instance_storage is false."
  }
}

# ──────────────────────────────────────────────
# run: existing launch template (bypass module-managed LT)
# ──────────────────────────────────────────────

run "existing_launch_template" {
  command = plan

  variables {
    bucket_name     = "existing-lt-tiles-bucket"
    launch_template = { existing_id = "lt-0existingabcdef123" }
  }

  assert {
    condition     = length(aws_launch_template.batch) == 0
    error_message = "No launch template should be created when existing_id is set."
  }
}


run "custom_ami" {
  command = plan

  variables {
    bucket_name     = "custom-ami-tiles-bucket"
    launch_template = { ami_id = "ami-custom0123456789ab" }
  }

  assert {
    condition     = aws_launch_template.batch[0].image_id == "ami-custom0123456789ab"
    error_message = "Launch template should use the custom ami_id when provided."
  }
}

# ──────────────────────────────────────────────
# run: custom container image
# ──────────────────────────────────────────────

run "custom_container_image" {
  command = apply

  variables {
    bucket_name     = "custom-image-tiles-bucket"
    container_image = "123456789012.dkr.ecr.us-east-1.amazonaws.com/overture-tiles:v2.0.0"
    themes          = ["base"]
  }

  assert {
    condition     = strcontains(aws_batch_job_definition.tiles["base"].container_properties, "123456789012.dkr.ecr.us-east-1.amazonaws.com/overture-tiles:v2.0.0")
    error_message = "Job definition should use the custom container_image."
  }
}
