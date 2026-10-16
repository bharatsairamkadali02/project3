
variable "aws_region" {
  description = "AWS region for the portfolio website"
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Name used to identify Project 2 resources"
  type        = string
  default     = "portfolio-project2-s3"
}

variable "bucket_name" {
  description = "Globally unique S3 bucket name for the website"
  type        = string

  validation {
    condition = (
      length(var.bucket_name) >= 3 &&
      length(var.bucket_name) <= 63 &&
      can(regex(
        "^[a-z0-9][a-z0-9.-]*[a-z0-9]$",
        var.bucket_name
      ))
    )

    error_message = "Bucket name must be 3-63 characters, using lowercase letters, numbers, dots, or hyphens."
  }
}
