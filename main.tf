terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
}

resource "aws_s3_bucket" "vaibhav-jain-online" {
  bucket = "vaibhav-jain-online"
}

resource "aws_s3_bucket_public_access_block" "public_access" {
  bucket = aws_s3_bucket.vaibhav-jain-online.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

#bucket policy
resource "aws_s3_bucket_policy" "bucket_policy" {
  bucket = aws_s3_bucket.vaibhav-jain-online.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = {
          AWS = aws_cloudfront_origin_access_identity.origin_access_identity.iam_arn
        }
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.vaibhav-jain-online.arn}/*"
      }
    ]
  })
}
#uploading content and point it to index html page
resource "aws_s3_bucket_website_configuration" "website" {
  bucket = aws_s3_bucket.vaibhav-jain-online.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

resource "aws_s3_object" "website_files" {
  for_each = fileset("D:/Users/vjain/static-website-terraform/static-website", "**/*")

  bucket       = aws_s3_bucket.vaibhav-jain-online.bucket
  key          = each.value
  source       = "D:/Users/vjain/static-website-terraform/static-website/${each.value}"
  etag         = filemd5("D:/Users/vjain/static-website-terraform/static-website/${each.value}")
  content_type = lookup(local.mime_types, regex("\\.[^.]+$", each.value), null)
}

locals {
  mime_types = {
    ".html" = "text/html"
    ".css"  = "text/css"
    ".js"   = "application/javascript"
    ".png"  = "image/png"
    ".jpg"  = "image/jpeg"
    ".gif"  = "image/gif"
  }
}
#cloudfront declaration
resource "aws_cloudfront_distribution" "cdn" {
  origin {
    domain_name = aws_s3_bucket.vaibhav-jain-online.bucket_regional_domain_name
    origin_id   = "S3-${aws_s3_bucket.vaibhav-jain-online.id}"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.origin_access_identity.cloudfront_access_identity_path
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.vaibhav-jain-online.id}"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

resource "aws_cloudfront_origin_access_identity" "origin_access_identity" {
  comment = "Access S3 bucket for CloudFront"
}

output "cloudfront_domain_name" {
  value = aws_cloudfront_distribution.cdn.domain_name
}

output "s3_website_endpoint" {
  value = aws_s3_bucket_website_configuration.website.website_endpoint
}