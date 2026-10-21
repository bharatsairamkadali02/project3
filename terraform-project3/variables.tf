variable "aws_region" {
  description = "AWS region for the portfolio website"
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Project identifier used to tag AWS resources"
  type        = string
  default     = "portfolio-project3"
}

variable "instance_type" {
  description = "EC2 instance size"
  type        = string
  default     = "t3.micro"
}

variable "assets_bucket_name" {
  description = "Globally unique S3 bucket name for portfolio static assets (images, PDF)"
  type        = string
}

variable "github_repo_url" {
  description = "Public GitHub repository URL"
  type        = string
  default     = "https://github.com/bharatsairamkadali02/project3.git"
}

variable "github_branch" {
  description = "Git branch containing the website"
  type        = string
  default     = "project3-hybrid-vm-s3"
}
