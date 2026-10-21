output "ec2_public_ip" {
  description = "Public IP address of the EC2 Nginx server"
  value       = aws_instance.portfolio.public_ip
}

output "ec2_instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.portfolio.id
}

output "portfolio_url" {
  description = "Public URL of the portfolio website"
  value       = "http://${aws_instance.portfolio.public_ip}"
}

output "assets_bucket_name" {
  description = "Name of the S3 bucket that stores portfolio assets"
  value       = aws_s3_bucket.assets.id
}

output "assets_bucket_url" {
  description = "Base URL for accessing assets stored in S3"
  value       = "https://${aws_s3_bucket.assets.bucket}.s3.${var.aws_region}.amazonaws.com"
}
