
output "instance_id" {
  description = "ID of the portfolio EC2 instance"
  value       = aws_instance.portfolio.id
}

output "public_ip" {
  description = "Public IP address of the portfolio website"
  value       = aws_instance.portfolio.public_ip
}

output "website_url" {
  description = "URL of the live portfolio"
  value       = "http://${aws_instance.portfolio.public_ip}"
}

output "ssm_role_name" {
  description = "IAM role attached to the EC2 instance"
  value       = aws_iam_role.ec2_ssm_role.name
}
