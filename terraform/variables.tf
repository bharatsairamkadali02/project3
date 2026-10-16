
variable "aws_region" {
  description = "AWS region for the portfolio website"
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Unique project identifier used for AWS resource tags"
  type        = string
  default     = "portfolio-cicd"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "github_repo_url" {
  description = "Public GitHub repository to deploy"
  type        = string
}

variable "github_branch" {
  description = "Git branch containing the website"
  type        = string
  default     = "main"
}
