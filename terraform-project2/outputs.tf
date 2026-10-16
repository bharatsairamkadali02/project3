
output "website_bucket_name" {
  description = "S3 website bucket name"
  value       = aws_s3_bucket.portfolio.bucket
}

output "website_endpoint" {
  description = "S3 static website endpoint"
  value       = aws_s3_bucket_website_configuration.portfolio.website_endpoint
}

output "website_url" {
  description = "Portfolio website URL"
  value       = "http://${aws_s3_bucket_website_configuration.portfolio.website_endpoint}"
}
