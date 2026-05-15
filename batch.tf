data "aws_region" "current" {}

# ECS-optimised Amazon Linux 2023 ARM64 AMI – used when no custom ami_id is supplied.
# c7gd (Graviton3 + NVMe instance store) requires an ARM64 image.
data "aws_ssm_parameter" "ecs_optimized_ami" {
  count = var.ami_id == null ? 1 : 0
  name  = "/aws/service/ecs/optimized-ami/amazon-linux-2023/arm64/recommended/image_id"
}

locals {
  resolved_ami_id = var.ami_id != null ? var.ami_id : data.aws_ssm_parameter.ecs_optimized_ami[0].value

  # User data that formats the NVMe instance-store volume as ext4 and mounts it
  # as the Docker data root. This maximises available scratch space on
  # NVMe-backed instance families (c7gd, im4gn, etc.).
  #
  # The script picks the largest block device reported by lsblk so it works
  # across instance sizes that expose different device names.
  instance_storage_user_data = base64encode(join("\n", [
    "Content-Type: multipart/mixed; boundary=\"==BOUNDARY==\"",
    "MIME-Version: 1.0",
    "",
    "--==BOUNDARY==",
    "Content-Type: text/x-shellscript; charset=\"us-ascii\"",
    "",
    "#!/bin/bash",
    "set -euo pipefail",
    "volume_name=$(lsblk -x SIZE -o NAME | tail -n 1)",
    "mkfs -t ext4 /dev/$volume_name",
    "mkdir -p /docker",
    "mount /dev/$volume_name /docker",
    "echo '{\"data-root\": \"/docker\"}' > /etc/docker/daemon.json",
    "systemctl restart docker",
    "",
    "--==BOUNDARY==--",
  ]))

  resolved_log_group_name           = coalesce(var.cloudwatch_log_group_name, "/aws/batch/${var.name_prefix}")
  resolved_launch_template_name_pfx = coalesce(var.launch_template_name_prefix, "${var.name_prefix}-")
  resolved_compute_env_name_pfx     = coalesce(var.compute_env_name_prefix, "${var.name_prefix}-")
}

resource "aws_launch_template" "batch" {
  name_prefix = local.resolved_launch_template_name_pfx
  image_id    = local.resolved_ami_id
  user_data   = var.configure_instance_storage ? local.instance_storage_user_data : null

  dynamic "block_device_mappings" {
    for_each = var.ebs_device_name != null ? [1] : []
    content {
      device_name = var.ebs_device_name

      ebs {
        volume_size           = var.ebs_volume_size_gb
        volume_type           = var.ebs_volume_type
        iops                  = var.ebs_iops
        throughput            = var.ebs_throughput
        delete_on_termination = true
        encrypted             = true
      }
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
  service_role = var.service_role_arn

  compute_resources {
    type                = var.use_spot ? "SPOT" : "EC2"
    allocation_strategy = var.use_spot ? "SPOT_CAPACITY_OPTIMIZED" : "BEST_FIT"
    max_vcpus           = var.max_vcpus
    min_vcpus           = 0
    instance_type       = var.instance_types
    instance_role       = aws_iam_instance_profile.ecs.arn
    subnets             = local.subnet_ids
    security_group_ids  = [aws_security_group.batch.id]

    launch_template {
      launch_template_id = aws_launch_template.batch.id
      version            = "$Latest"
    }

    dynamic "ec2_configuration" {
      for_each = var.ec2_image_type != null ? [1] : []
      content {
        image_type = var.ec2_image_type
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
