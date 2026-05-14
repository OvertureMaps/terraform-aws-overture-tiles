resource "aws_s3_bucket" "tiles" {
  bucket = var.bucket_name
  tags   = var.tags
}

resource "aws_s3_bucket_public_access_block" "tiles" {
  bucket = aws_s3_bucket.tiles.id

  block_public_acls       = !var.public_access_enabled
  block_public_policy     = !var.public_access_enabled
  ignore_public_acls      = !var.public_access_enabled
  restrict_public_buckets = !var.public_access_enabled
}

resource "aws_s3_bucket_cors_configuration" "tiles" {
  bucket = aws_s3_bucket.tiles.id

  cors_rule {
    allowed_methods = ["GET"]
    allowed_origins = var.cors_allowed_origins
  }
}

# Bucket policy: public-read statement and/or CloudFront OAC statement.
# Only created when at least one of the two options is enabled.
locals {
  bucket_policy_public_read = var.public_access_enabled ? [jsonencode({
    Sid       = "PublicReadGetObject"
    Effect    = "Allow"
    Principal = "*"
    Action    = "s3:GetObject"
    Resource  = "${aws_s3_bucket.tiles.arn}/*"
  })] : []

  bucket_policy_cloudfront_oac = var.create_cloudfront_distribution ? [jsonencode({
    Sid    = "CloudFrontOAC"
    Effect = "Allow"
    Principal = {
      Service = "cloudfront.amazonaws.com"
    }
    Action   = "s3:GetObject"
    Resource = "${aws_s3_bucket.tiles.arn}/*"
    Condition = {
      StringEquals = {
        "AWS:SourceArn" = aws_cloudfront_distribution.tiles[0].arn
      }
    }
  })] : []
}

resource "aws_s3_bucket_policy" "tiles" {
  count = (var.public_access_enabled || var.create_cloudfront_distribution) ? 1 : 0

  bucket = aws_s3_bucket.tiles.id
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = concat(local.bucket_policy_public_read, local.bucket_policy_cloudfront_oac)
  })

  # Ensure the public-access block is applied before the policy is set.
  depends_on = [aws_s3_bucket_public_access_block.tiles]
}
