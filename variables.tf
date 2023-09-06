# # Input variable definitions

variable "aws_region" {
  description = "AWS region for all resources."

  type    = string
  default = "us-east-1"
}

variable "s3_bucket_name" {
  description = "S3 bucket name"
  type = string
  default = "s3-bucket-darwin-dev"
  
}