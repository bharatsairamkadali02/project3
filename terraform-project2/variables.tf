
variable "aws_region" {
  description = "AWS region for the portfolio website"
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Project name for AWS resource tags"
  type        = string
  default     = "portfolio-project2-s3"
}

variable "bucket_name" {
  description = "Globally unique S3 website bucket name"
  type        = string
}
