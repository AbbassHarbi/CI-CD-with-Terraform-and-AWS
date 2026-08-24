terraform {
  required_version = ">= 1.6.0, < 2.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">5.0, <=6.1"
    }
  }
  backend "s3" {
    key = "aws/ec2-deployment/terraform.tfstate"
  }
}

provider "aws" {
  region = var.region
}

resource "aws_instance" "server" {
  ami                    = "ami-0b6d9d3d33ba97d99"
  instance_type          = "t3.micro"
  vpc_security_group_ids = [aws_security_group.SG1.id]
  iam_instance_profile   = aws_iam_instance_profile.EC2ECR_IAMInstProf.name

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "disabled"
  }
  ebs_optimized = true
  root_block_device {
    encrypted   = true
    volume_type = "gp3"
  }

  tags = {
    Name        = "ec2_1"
    Environment = "dev"
  }
}


resource "aws_security_group" "SG1" {
  description = "CI/CD application server: public HTTP (port 80) only; management via SSM"
  egress = [
    {
      cidr_blocks      = ["0.0.0.0/0"]
      description      = "Outbound Connection for our EC2 Instance"
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      ipv6_cidr_blocks = []
      self             = false
      prefix_list_ids  = []
      security_groups  = []

    }
  ]
  ingress = [
    {
      cidr_blocks      = ["0.0.0.0/0"]
      from_port        = 80
      to_port          = 80
      protocol         = "tcp"
      prefix_list_ids  = []
      self             = false
      ipv6_cidr_blocks = []
      security_groups  = []
      description      = "Allow HTTP inbound traffic to our EC2"
    }
  ]
}

resource "aws_iam_instance_profile" "EC2ECR_IAMInstProf" {
  name = "EC2ECR_IAMInstProf"
  role = "EC2ECR-AUTH"
}

output "instance_id" {
  value       = aws_instance.server.id
  description = "EC2 instance ID used as the Systems Manager command target"
}