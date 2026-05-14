resource "aws_cloudfront_origin_access_control" "tiles" {
  count = var.create_cloudfront_distribution ? 1 : 0

  name                              = "${var.name_prefix}-oac"
  description                       = "OAC for ${var.name_prefix} S3 bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "tiles" {
  count = var.create_cloudfront_distribution ? 1 : 0

  enabled     = true
  price_class = var.cloudfront_price_class
  comment     = "${var.name_prefix} tiles distribution"

  origin {
    domain_name              = aws_s3_bucket.tiles.bucket_regional_domain_name
    origin_id                = "s3-${var.bucket_name}"
    origin_access_control_id = aws_cloudfront_origin_access_control.tiles[0].id
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "s3-${var.bucket_name}"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 86400
    max_ttl     = 31536000
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = var.tags
}
