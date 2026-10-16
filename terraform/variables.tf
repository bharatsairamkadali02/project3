variable "aws_region" {
  description = "AWS region for the portfolio website"
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Project identifier used to tag AWS resources"
  type        = string
  default     = "portfolio-cicd"
}

variable "instance_type" {
  description = "EC2 instance size"
  type        = string
  default     = "t3.micro"
}

variable "github_repo_url" {
  description = "Public GitHub repository URL"
  type        = string
}

variable "github_branch" {
  description = "Git branch containing the website"
  type        = string
  default     = "main"
}