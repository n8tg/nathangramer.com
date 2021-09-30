terraform {
  backend "remote" {
    hostname     = "n8tg.scalr.io"
    organization = "env-tbft8jb4tcn20pg"
    workspaces {
      name = "Personal-Website"
    }
  }
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_s3_bucket" "Redirect_S3_Bucket" {
  bucket_prefix = var.sourceURL
  acl           = "public-read"
  website {
    redirect_all_requests_to = var.targetURL
  }
}

resource "aws_cloudfront_distribution" "cloudfront" {
  origin {
    domain_name = aws_s3_bucket.Redirect_S3_Bucket.website_endpoint
    origin_id   = "s3_redirect_bucket"

    custom_origin_config {
      origin_protocol_policy = "http-only"
      http_port              = "80"
      https_port             = "443"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }
  enabled         = true
  is_ipv6_enabled = false

  aliases = [var.sourceURL]

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "s3_redirect_bucket"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }
  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate.acm_certificate.arn
    minimum_protocol_version = "TLSv1.2_2019"
    ssl_support_method       = "sni-only"
  }
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
}

resource "aws_acm_certificate" "acm_certificate" {
  domain_name       = var.sourceURL
  validation_method = "DNS"
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate_validation" "acm_certificate_validation" {
  certificate_arn         = aws_acm_certificate.acm_certificate.arn
  validation_record_fqdns = [for record in aws_route53_record.dns_certificate_validator : record.fqdn]
}

resource "aws_route53_record" "dns_certificate_validator" {
  for_each = {
    for dvo in aws_acm_certificate.acm_certificate.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.source_dns_zone.zone_id
}
resource "aws_route53_zone" "source_dns_zone" {
  name = var.sourceURL
}

resource "aws_route53_record" "dns" {
  zone_id = aws_route53_zone.source_dns_zone.zone_id
  name    = var.sourceURL
  type    = "A"
  alias {
    zone_id                = aws_cloudfront_distribution.cloudfront.hosted_zone_id
    name                   = aws_cloudfront_distribution.cloudfront.domain_name
    evaluate_target_health = true
  }
}

