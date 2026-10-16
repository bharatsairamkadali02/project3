
output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.portfolio.id
}

output "public_ip" {
  description = "Public IP address of the portfolio EC2 instance"
  value       = aws_instance.portfolio.public_ip
}

output "website_url" {
  description = "Portfolio website URL"
  value       = "http://${aws_instance.portfolio.public_ip}"
}

output "ssm_role_name" {
  description = "Existing IAM role attached to EC2 for Systems Manager"
  value       = data.aws_iam_role.ec2_ssm_role.name
}
