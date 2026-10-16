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

# Find an available Availability Zone.
data "aws_availability_zones" "available" {
  state = "available"
}

# Find the latest official Ubuntu 24.04 LTS AMI.
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

# 1. Create a VPC.
resource "aws_vpc" "portfolio_vpc" {
  cidr_block           = "10.20.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name    = "${var.project_name}-vpc"
    Project = var.project_name
  }
}

# 2. Create a public subnet.
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.portfolio_vpc.id
  cidr_block              = "10.20.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name    = "${var.project_name}-public-subnet"
    Project = var.project_name
  }
}

# 3. Create an internet gateway.
resource "aws_internet_gateway" "portfolio_igw" {
  vpc_id = aws_vpc.portfolio_vpc.id

  tags = {
    Name    = "${var.project_name}-igw"
    Project = var.project_name
  }
}

# 4. Configure the public route table.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.portfolio_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.portfolio_igw.id
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

# 5. Allow HTTP access.
# SSH is not opened; deployment uses Systems Manager.
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
    description = "Outbound connections for updates and SSM"
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

# 6. Create an IAM role for the EC2 SSM agent.

# 6. Reuse the existing EC2 IAM role.
# This role already exists in your AWS account.
data "aws_iam_role" "ec2_ssm_role" {
  name = "${var.project_name}-ssm-role"
}

# Attach the required SSM permissions to the existing role.
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = data.aws_iam_role.ec2_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# 7. Reuse the existing instance profile.
data "aws_iam_instance_profile" "portfolio_profile" {
  name = "${var.project_name}-instance-profile"
}


resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "portfolio_profile" {
  name = "${var.project_name}-instance-profile"
  role = aws_iam_role.ec2_ssm_role.name
}

# 7. Create the Ubuntu EC2 instance.
resource "aws_instance" "portfolio" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.portfolio_sg.id]
  iam_instance_profile = data.aws_iam_instance_profile.portfolio_profile.name
  associate_public_ip_address = true

  user_data_replace_on_change = true

  # Install Nginx, Git, rsync, and the SSM agent.
  # The GitHub Actions workflow will clone and deploy the website.
  user_data = <<-EOF
    #!/bin/bash
    set -eux

    exec > >(tee -a /var/log/portfolio-setup.log) 2>&1

    export DEBIAN_FRONTEND=noninteractive

    apt-get update
    apt-get install -y nginx git rsync curl snapd

    systemctl enable --now nginx

    # Use the existing SSM agent if installed;
    # otherwise install it using Snap.
    if systemctl list-unit-files | grep -q '^amazon-ssm-agent.service'; then
      systemctl enable --now amazon-ssm-agent
    else
      if ! snap list amazon-ssm-agent >/dev/null 2>&1; then
        snap install amazon-ssm-agent --classic
      fi

      systemctl enable --now snap.amazon-ssm-agent.amazon-ssm-agent.service
    fi
  EOF

  depends_on = [
    aws_route_table_association.public,
    aws_iam_role_policy_attachment.ssm_core
  ]

  tags = {
    Name    = "${var.project_name}-ec2"
    Project = var.project_name
  }
}