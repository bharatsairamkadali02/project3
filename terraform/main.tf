
terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Persistent Terraform state.
  # GitHub Actions supplies the backend configuration.
  backend "s3" {}
}

provider "aws" {
  region = var.aws_region
}

# 1. Create the S3 bucket for the portfolio website.
resource "aws_s3_bucket" "portfolio" {
  bucket        = var.bucket_name
  force_destroy = true

  tags = {
    Name      = var.project_name
    Project   = var.project_name
    ManagedBy = "Terraform"
  }
}

# 2. Configure S3 static website hosting.
resource "aws_s3_bucket_website_configuration" "portfolio" {
  bucket = aws_s3_bucket.portfolio.id

  index_document {
    suffix = "index.html"
  }
}

# 3. Configure public access settings for the website bucket.
# Public reads are granted through the bucket policy below.
resource "aws_s3_bucket_public_access_block" "portfolio" {
  bucket = aws_s3_bucket.portfolio.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = false
  restrict_public_buckets = false
}

# 4. Allow visitors to read published website objects.
resource "aws_s3_bucket_policy" "portfolio" {
  bucket = aws_s3_bucket.portfolio.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid       = "AllowPublicWebsiteRead"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.portfolio.arn}/*"
      }
    ]
  })

  depends_on = [
    aws_s3_bucket_public_access_block.portfolio
  ]
}
