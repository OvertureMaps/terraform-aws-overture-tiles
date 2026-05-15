# ──────────────────────────────────────────────
# ECS task role – used by the tile-gen container for S3 write access
# ──────────────────────────────────────────────

resource "aws_iam_role" "job" {
  name        = var.name_overrides.job_role
  name_prefix = var.name_overrides.job_role == null ? "${var.name_prefix}-job-" : null
  description = var.name_overrides.job_role_description

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "ECSTaskAssumeRole"
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
  tags = var.tags
}

locals {
  tiles_bucket_arn = var.create_s3_bucket ? aws_s3_bucket.tiles[0].arn : "arn:aws:s3:::${var.bucket_name}"
}

resource "aws_iam_role_policy" "job_s3" {
  name        = var.name_overrides.job_role_policy
  name_prefix = var.name_overrides.job_role_policy == null ? "${var.name_prefix}-s3-" : null
  role        = aws_iam_role.job.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "AllowTileUpload"
      Effect   = "Allow"
      Action   = ["s3:PutObject", "s3:PutObjectAcl"]
      Resource = "${local.tiles_bucket_arn}/*"
    }]
  })
}

# ──────────────────────────────────────────────
# ECS task execution role – used by the ECS agent to pull images and write logs
# ──────────────────────────────────────────────

resource "aws_iam_role" "execution" {
  name        = var.name_overrides.execution_role
  name_prefix = var.name_overrides.execution_role == null ? "${var.name_prefix}-execution-" : null

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "ECSTaskAssumeRole"
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy" "execution_logs" {
  name        = var.name_overrides.execution_role_policy
  name_prefix = var.name_overrides.execution_role_policy == null ? "${var.name_prefix}-logs-" : null
  role        = aws_iam_role.execution.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "AllowCloudWatchLogs"
      Effect   = "Allow"
      Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
      Resource = "${aws_cloudwatch_log_group.batch.arn}:*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "execution_ecr" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# ──────────────────────────────────────────────
# EC2 instance role – assumed by the ECS agent running on each Batch worker
# ──────────────────────────────────────────────

resource "aws_iam_role" "ecs_instance" {
  name        = var.name_overrides.instance_role
  name_prefix = var.name_overrides.instance_role == null ? "${var.name_prefix}-ecs-instance-" : null

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "EC2AssumeRole"
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "ecs_instance" {
  role       = aws_iam_role.ecs_instance.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "ecs" {
  name        = var.name_overrides.instance_profile
  name_prefix = var.name_overrides.instance_profile == null ? "${var.name_prefix}-" : null
  role        = aws_iam_role.ecs_instance.name
  tags        = var.tags
}
