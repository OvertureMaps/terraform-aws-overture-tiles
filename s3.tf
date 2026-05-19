resource "aws_s3_bucket" "tiles" {
  count  = var.create_s3_bucket ? 1 : 0
  bucket = var.bucket_name
  tags   = var.tags
}

resource "aws_s3_bucket_public_access_block" "tiles" {
  count  = var.create_s3_bucket ? 1 : 0
  bucket = aws_s3_bucket.tiles[0].id

  block_public_acls       = !var.public_access_enabled
  block_public_policy     = !var.public_access_enabled
  ignore_public_acls      = !var.public_access_enabled
  restrict_public_buckets = !var.public_access_enabled
}

resource "aws_s3_bucket_cors_configuration" "tiles" {
  count  = var.create_s3_bucket ? 1 : 0
  bucket = aws_s3_bucket.tiles[0].id

  cors_rule {
    allowed_methods = ["GET"]
    allowed_origins = var.cors_allowed_origins
  }
}

# Bucket policy: public-read statement and/or CloudFront OAC statement.
# Only created when at least one of the two options is enabled.
data "aws_iam_policy_document" "tiles_bucket" {
  count = var.create_s3_bucket && (var.public_access_enabled || var.create_cloudfront_distribution) ? 1 : 0

  dynamic "statement" {
    for_each = var.public_access_enabled ? [1] : []
    content {
      sid    = "PublicReadGetObject"
      effect = "Allow"
      principals {
        type        = "*"
        identifiers = ["*"]
      }
      actions   = ["s3:GetObject"]
      resources = ["${local.tiles_bucket_arn}/*"]
    }
  }

  dynamic "statement" {
    for_each = var.create_cloudfront_distribution ? [1] : []
    content {
      sid    = "CloudFrontOAC"
      effect = "Allow"
      principals {
        type        = "Service"
        identifiers = ["cloudfront.amazonaws.com"]
      }
      actions   = ["s3:GetObject"]
      resources = ["${local.tiles_bucket_arn}/*"]
      condition {
        test     = "StringEquals"
        variable = "AWS:SourceArn"
        values   = [aws_cloudfront_distribution.tiles[0].arn]
      }
    }
  }
}

resource "aws_s3_bucket_policy" "tiles" {
  count = var.create_s3_bucket && (var.public_access_enabled || var.create_cloudfront_distribution) ? 1 : 0

  bucket = aws_s3_bucket.tiles[0].id
  policy = data.aws_iam_policy_document.tiles_bucket[0].json

  # Ensure the public-access block is applied before the policy is set.
  depends_on = [aws_s3_bucket_public_access_block.tiles]
}
