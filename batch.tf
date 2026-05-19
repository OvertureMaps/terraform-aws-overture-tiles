data "aws_region" "current" {}

# ECS-optimised Amazon Linux 2023 ARM64 AMI – used when no custom ami_id is supplied.
# c7gd (Graviton3 + NVMe instance store) requires an ARM64 image.
data "aws_ssm_parameter" "ecs_optimized_ami" {
  count = (var.launch_template.existing_id == null && var.launch_template.ami_id == null) ? 1 : 0
  name  = "/aws/service/ecs/optimized-ami/amazon-linux-2023/arm64/recommended/image_id"
}

locals {
  resolved_ami_id = var.launch_template.ami_id != null ? var.launch_template.ami_id : (
    length(data.aws_ssm_parameter.ecs_optimized_ami) > 0 ? data.aws_ssm_parameter.ecs_optimized_ami[0].value : null
  )

  resolved_log_group_name       = coalesce(var.name_overrides.cloudwatch_log_group, "/aws/batch/${var.name_prefix}")
  resolved_lt_name_pfx          = coalesce(var.launch_template.name_prefix, "${var.name_prefix}-")
  resolved_compute_env_name_pfx = coalesce(var.compute_environment.name_prefix, "${var.name_prefix}-")
}

# AWS Batch requires UserData in MIME multipart format — it merges its own ECS
# agent bootstrap content with any user-supplied script at launch time.
# cloudinit_config handles boundary generation and base64 encoding automatically.
data "cloudinit_config" "batch" {
  count = (var.launch_template.existing_id == null && var.launch_template.user_data != null) ? 1 : 0

  gzip          = false
  base64_encode = true

  part {
    content_type = "text/x-shellscript"
    content      = var.launch_template.user_data
  }
}

resource "aws_launch_template" "batch" {
  count = var.launch_template.existing_id == null ? 1 : 0

  name_prefix = local.resolved_lt_name_pfx
  image_id    = local.resolved_ami_id
  user_data = length(data.cloudinit_config.batch) > 0 ? data.cloudinit_config.batch[0].rendered : null

  dynamic "block_device_mappings" {
    for_each = var.ebs_volume != null ? [var.ebs_volume] : []
    content {
      device_name = block_device_mappings.value.device_name

      ebs {
        volume_size           = block_device_mappings.value.size_gb
        volume_type           = block_device_mappings.value.type
        iops                  = block_device_mappings.value.iops
        throughput            = block_device_mappings.value.throughput
        delete_on_termination = true
        encrypted             = true
      }
    }
  }

  dynamic "tag_specifications" {
    for_each = var.launch_template.tag_specifications != null ? var.launch_template.tag_specifications : []
    content {
      resource_type = tag_specifications.value.resource_type
      tags          = tag_specifications.value.tags
    }
  }

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "batch" {
  name              = local.resolved_log_group_name
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

# One job definition per theme.
resource "aws_batch_job_definition" "tiles" {
  for_each = toset(var.themes)

  name                  = lookup(var.job_definition_name_overrides, each.key, "${var.name_prefix}-${each.key}")
  type                  = "container"
  platform_capabilities = ["EC2"]

  container_properties = jsonencode({
    image            = var.container_image
    jobRoleArn       = aws_iam_role.job.arn
    executionRoleArn = aws_iam_role.execution.arn

    resourceRequirements = [
      {
        type  = "VCPU"
        value = tostring(var.job_vcpus)
      },
      {
        type  = "MEMORY"
        value = tostring(var.job_memory_gib * 1024)
      }
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.batch.name
        "awslogs-region"        = data.aws_region.current.id
        "awslogs-stream-prefix" = each.key
      }
    }
  })

  tags = var.tags
}

resource "aws_batch_compute_environment" "tiles" {
  name_prefix  = local.resolved_compute_env_name_pfx
  type         = "MANAGED"
  service_role = var.compute_environment.service_role_arn

  compute_resources {
    type                = var.compute_environment.use_spot ? "SPOT" : "EC2"
    allocation_strategy = var.compute_environment.use_spot ? "SPOT_CAPACITY_OPTIMIZED" : "BEST_FIT"
    max_vcpus           = var.compute_environment.max_vcpus
    min_vcpus           = 0
    instance_type       = var.compute_environment.instance_types
    instance_role       = aws_iam_instance_profile.ecs.arn
    subnets             = local.subnet_ids
    security_group_ids  = [aws_security_group.batch.id]

    launch_template {
      launch_template_id = var.launch_template.existing_id != null ? var.launch_template.existing_id : aws_launch_template.batch[0].id
      version            = var.launch_template.version
    }

    dynamic "ec2_configuration" {
      for_each = var.compute_environment.ec2_image_type != null ? [1] : []
      content {
        image_type = var.compute_environment.ec2_image_type
      }
    }
  }

  tags = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_batch_job_queue" "tiles" {
  name     = "${var.name_prefix}-queue"
  state    = "ENABLED"
  priority = 1

  compute_environment_order {
    order               = 1
    compute_environment = aws_batch_compute_environment.tiles.arn
  }

  tags = var.tags
}
