# ──────────────────────────────────────────────
# ECS task role – used by the tile-gen container for S3 write access
# ──────────────────────────────────────────────

resource "aws_iam_role" "job" {
  name_prefix = "${var.name_prefix}-job-"
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

resource "aws_iam_role_policy" "job_s3" {
  name_prefix = "${var.name_prefix}-s3-"
  role        = aws_iam_role.job.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "AllowTileUpload"
      Effect   = "Allow"
      Action   = ["s3:PutObject", "s3:PutObjectAcl"]
      Resource = "${aws_s3_bucket.tiles.arn}/*"
    }]
  })
}

# ──────────────────────────────────────────────
# ECS task execution role – used by the ECS agent to pull images and write logs
# ──────────────────────────────────────────────

resource "aws_iam_role" "execution" {
  name_prefix = "${var.name_prefix}-execution-"
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
  name_prefix = "${var.name_prefix}-logs-"
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
  name_prefix = "${var.name_prefix}-ecs-instance-"
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
  name_prefix = "${var.name_prefix}-"
  role        = aws_iam_role.ecs_instance.name
  tags        = var.tags
}
