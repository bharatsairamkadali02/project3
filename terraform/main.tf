
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

# Select an available Availability Zone.
data "aws_availability_zones" "available" {
  state = "available"
}

# Find an official Ubuntu 24.04 LTS AMI.
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

# -------------------------------
# 1. VPC and public networking
# -------------------------------

resource "aws_vpc" "portfolio_vpc" {
  cidr_block           = "10.20.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name    = "${var.project_name}-vpc"
    Project = var.project_name
  }
}

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

resource "aws_internet_gateway" "portfolio_igw" {
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

# -------------------------------
# 2. Security group
# -------------------------------

resource "aws_security_group" "portfolio_sg" {
  name        = "${var.project_name}-sg"
  description = "Allow public HTTP access to the portfolio"
  vpc_id      = aws_vpc.portfolio_vpc.id

  ingress {
    description = "HTTP website"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # No inbound SSH rule is necessary.
  # GitHub Actions deploys through AWS Systems Manager.

  egress {
    description = "Allow outbound traffic"
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

# -------------------------------
# 3. IAM role for AWS SSM
# -------------------------------

resource "aws_iam_role" "ec2_ssm_role" {
  name = "${var.project_name}-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"

      Principal = {
        Service = "ec2.amazonaws.com"
      }

      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Project = var.project_name
  }
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "portfolio_profile" {
  name = "${var.project_name}-instance-profile"
  role = aws_iam_role.ec2_ssm_role.name
}

# -------------------------------
# 4. Ubuntu EC2 instance
# -------------------------------

resource "aws_instance" "portfolio" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.portfolio_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.portfolio_profile.name
  associate_public_ip_address = true

  user_data_replace_on_change = true

  user_data = <<-EOF
    #!/bin/bash
    set -euxo pipefail

    exec > >(tee -a /var/log/portfolio-setup.log) 2>&1

    export DEBIAN_FRONTEND=noninteractive

    # Install website deployment tools.
    apt-get update
    apt-get install -y nginx git rsync curl snapd

    systemctl enable --now nginx

    # Ensure that the AWS SSM agent is available.
    if ! snap list amazon-ssm-agent >/dev/null 2>&1; then
      snap install amazon-ssm-agent --classic
    fi

    systemctl enable --now snap.amazon-ssm-agent.amazon-ssm-agent.service

    # Clone the public repository on the EC2 machine.
    mkdir -p /opt/portfolio

    if [ ! -d /opt/portfolio/.git ]; then
      git clone \
        --depth 1 \
        --branch "${var.github_branch}" \
        "${var.github_repo_url}" \
        /opt/portfolio
    fi

    # Publish the website files to the Nginx web root.
    rsync -av --delete \
      --exclude='.git/' \
      /opt/portfolio/ \
      /var/www/html/

    nginx -t
    systemctl restart nginx
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
