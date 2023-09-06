provider "aws" {
  profile = "default"
  region = var.aws_region

  # Make it faster by skipping something
  skip_metadata_api_check     = true
  skip_region_validation      = true
  skip_credentials_validation = true

  # skip_requesting_account_id should be disabled to generate valid ARN in apigatewayv2_api_execution_arn
  skip_requesting_account_id = false
}

module "cloudfront" {
  source = "terraform-aws-modules/cloudfront/aws"
  
  comment             = "Darwin dev distribution"
  enabled             = true
  http_version        = "http2"
  is_ipv6_enabled     = true
  price_class         = "PriceClass_All"
  retain_on_delete    = false
  wait_for_deployment = false

  default_root_object = "index.html"

  create_origin_access_identity = true
  origin_access_identities = {
    s3_bucket_one = "S3 bucket for Darwin dashboard assets"
  }

  origin = {
    s3_one = {
      domain_name = module.s3_bucket.s3_bucket_bucket_regional_domain_name
      s3_origin_config = {
        origin_access_identity = "s3_bucket_one"
      }
    }
  }
 
  default_cache_behavior = {
    target_origin_id           = "s3_one"
    viewer_protocol_policy     = "allow-all"

    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    cached_methods  = ["GET", "HEAD"]
    compress        = true
    query_string    = false

    # This is id for SecurityHeadersPolicy copied from https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/using-managed-response-headers-policies.html
    response_headers_policy_id = "5cc3b908-e619-4b99-88e5-2cf7f45965bd"

    function_association = {
      # Valid keys: viewer-request, viewer-response
      viewer-request = {
        function_arn = aws_cloudfront_function.nextjs.arn
      }
    }
  }

  custom_error_response = [{
    error_caching_min_ttl = 0
    error_code         = 403
    response_code      = 200
    response_page_path = "/404.html"
   }]
  
}

module "s3_bucket" {
  source = "terraform-aws-modules/s3-bucket/aws"

  bucket = var.s3_bucket_name
  force_destroy       = true
  
  tags = {
    Owner = "DARWIN"
  }
}

data "aws_iam_policy_document" "s3_policy" {
  # Origin Access Identities
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${module.s3_bucket.s3_bucket_arn}/*"]

    principals {
      type        = "AWS"
      identifiers = module.cloudfront.cloudfront_origin_access_identity_iam_arns
    }
  }
}

resource "aws_s3_bucket_policy" "bucket_policy" {
  bucket = module.s3_bucket.s3_bucket_id
  policy = data.aws_iam_policy_document.s3_policy.json
}

resource "aws_cloudfront_function" "nextjs" {
  name    = "nextjs-function"
  runtime = "cloudfront-js-1.0"
  code    = file("functions/nextjs_handler.js")
}