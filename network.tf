data "aws_availability_zones" "available" {
  count = var.create_vpc ? 1 : 0
  state = "available"
}

resource "aws_vpc" "batch" {
  count = var.create_vpc ? 1 : 0

  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.tags, { Name = "${var.name_prefix}-vpc" })
}

resource "aws_internet_gateway" "batch" {
  count  = var.create_vpc ? 1 : 0
  vpc_id = aws_vpc.batch[0].id
  tags   = merge(var.tags, { Name = "${var.name_prefix}-igw" })
}

# Single public subnet in the first available AZ. Batch jobs need internet
# access to reach S3 and ghcr.io – a public subnet avoids a NAT gateway cost.
resource "aws_subnet" "public" {
  count = var.create_vpc ? 1 : 0

  vpc_id                  = aws_vpc.batch[0].id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, 0)
  availability_zone       = data.aws_availability_zones.available[0].names[0]
  map_public_ip_on_launch = true

  tags = merge(var.tags, { Name = "${var.name_prefix}-public-0" })
}

resource "aws_route_table" "public" {
  count  = var.create_vpc ? 1 : 0
  vpc_id = aws_vpc.batch[0].id
  tags   = merge(var.tags, { Name = "${var.name_prefix}-rt" })
}

resource "aws_route" "internet" {
  count                  = var.create_vpc ? 1 : 0
  route_table_id         = aws_route_table.public[0].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.batch[0].id
}

resource "aws_route_table_association" "public" {
  count          = var.create_vpc ? 1 : 0
  subnet_id      = aws_subnet.public[0].id
  route_table_id = aws_route_table.public[0].id
}

# Security group for the Batch compute environment.
# Outbound-only: jobs pull data from S3 and ghcr.io, then push results to S3.
resource "aws_security_group" "batch" {
  name        = var.security_group_name
  name_prefix = var.security_group_name == null ? "${var.name_prefix}-batch-" : null
  description = "Outbound-only security group for ${var.name_prefix} Batch workers"
  vpc_id      = local.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-batch" })

  lifecycle {
    create_before_destroy = true
  }
}

locals {
  vpc_id     = var.create_vpc ? aws_vpc.batch[0].id : var.vpc_id
  subnet_ids = var.create_vpc ? [aws_subnet.public[0].id] : var.subnet_ids
}
