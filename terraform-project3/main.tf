terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ──────────────────────────────────────────────
# Data sources
# ──────────────────────────────────────────────

data "aws_availability_zones" "available" {
  state = "available"
}

# Latest official Ubuntu 24.04 LTS AMI.
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

# ──────────────────────────────────────────────
# Networking
# ──────────────────────────────────────────────

resource "aws_vpc" "portfolio_vpc" {
  cidr_block           = "10.30.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name    = "${var.project_name}-vpc"
    Project = var.project_name
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.portfolio_vpc.id
  cidr_block              = "10.30.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name    = "${var.project_name}-public-subnet"
    Project = var.project_name
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.portfolio_vpc.id

  tags = {
    Name    = "${var.project_name}-igw"
    Project = var.project_name
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.portfolio_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name    = "${var.project_name}-public-rt"
    Project = var.project_name
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# ──────────────────────────────────────────────
# Security group
# SSH is not opened; deployment uses Systems Manager.
# ──────────────────────────────────────────────

resource "aws_security_group" "portfolio_sg" {
  name        = "${var.project_name}-sg"
  description = "Allow HTTP access to the portfolio website"
  vpc_id      = aws_vpc.portfolio_vpc.id

  ingress {
    description = "Public HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Outbound connections for updates, SSM, and S3"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-sg"
    Project = var.project_name
  }
}

# ──────────────────────────────────────────────
# IAM: EC2 role with SSM + S3 read access
# ──────────────────────────────────────────────

resource "aws_iam_role" "ec2_role" {
  name = "${var.project_name}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Project = var.project_name
  }
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Allow EC2 to read objects from the assets S3 bucket.
resource "aws_iam_role_policy" "s3_read" {
  name = "${var.project_name}-s3-read"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:GetObject", "s3:ListBucket"]
      Resource = [
        aws_s3_bucket.assets.arn,
        "${aws_s3_bucket.assets.arn}/*"
      ]
    }]
  })
}

resource "aws_iam_instance_profile" "portfolio_profile" {
  name = "${var.project_name}-instance-profile"
  role = aws_iam_role.ec2_role.name

  tags = {
    Project = var.project_name
  }
}

# ──────────────────────────────────────────────
# S3 bucket for static assets (images, PDF)
# ──────────────────────────────────────────────

resource "aws_s3_bucket" "assets" {
  bucket        = var.assets_bucket_name
  force_destroy = true

  tags = {
    Name    = "${var.project_name}-assets"
    Project = var.project_name
  }
}

resource "aws_s3_bucket_public_access_block" "assets" {
  bucket = aws_s3_bucket.assets.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "assets_public_read" {
  bucket = aws_s3_bucket.assets.id

  # Wait until public access block is disabled before applying policy.
  depends_on = [aws_s3_bucket_public_access_block.assets]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "PublicReadGetObject"
      Effect    = "Allow"
      Principal = "*"
      Action    = "s3:GetObject"
      Resource  = "${aws_s3_bucket.assets.arn}/*"
    }]
  })
}

# Enable CORS so that the Nginx-served HTML can load images from S3.
resource "aws_s3_bucket_cors_configuration" "assets" {
  bucket = aws_s3_bucket.assets.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = ["*"]
    expose_headers  = []
    max_age_seconds = 3000
  }
}

# ──────────────────────────────────────────────
# EC2 instance
# ──────────────────────────────────────────────

resource "aws_instance" "portfolio" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.portfolio_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.portfolio_profile.name
  associate_public_ip_address = true

  user_data_replace_on_change = true

  # Bootstrap: install Nginx, Git, AWS CLI, rsync, and the SSM agent.
  # The CI/CD pipeline handles uploading assets to S3 and deploying HTML to Nginx.
  user_data = <<-EOF
    #!/bin/bash
    set -eux

    exec > >(tee -a /var/log/portfolio-setup.log) 2>&1

    export DEBIAN_FRONTEND=noninteractive

    apt-get update
    apt-get install -y nginx git rsync curl unzip snapd

    systemctl enable --now nginx

    # Install AWS CLI v2 for pulling objects from S3 on the instance if needed.
    if ! command -v aws > /dev/null 2>&1; then
      curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
      unzip -q /tmp/awscliv2.zip -d /tmp
      /tmp/aws/install
      rm -rf /tmp/aws /tmp/awscliv2.zip
    fi

    # SSM agent: use the pre-installed service or install via Snap.
    if systemctl list-unit-files | grep -q '^amazon-ssm-agent.service'; then
      systemctl enable --now amazon-ssm-agent
    else
      if ! snap list amazon-ssm-agent > /dev/null 2>&1; then
        snap install amazon-ssm-agent --classic
      fi
      systemctl enable --now snap.amazon-ssm-agent.amazon-ssm-agent.service
    fi
  EOF

  depends_on = [
    aws_route_table_association.public,
    aws_iam_role_policy_attachment.ssm_core,
    aws_iam_role_policy.s3_read
  ]

  tags = {
    Name    = "${var.project_name}-ec2"
    Project = var.project_name
  }
}
