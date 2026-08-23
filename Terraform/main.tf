terraform {
  required_version = ">= 1.6.0, < 2.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      region= var.region
      version = ">5.0, <=6.1"
    }
  }
  backend "s3" {
    key = "aws/ec2-deployment/terraform.tfstate"
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_instance" "server" {
  ami                    = "ami-0b6d9d3d33ba97d99"
  instance_type          = "t3.micro"
  key_name               = aws_key_pair.Kep1.key_name
  vpc_security_group_ids = [aws_security_group.SG1.id]
  iam_instance_profile   = aws_iam_instance_profile.EC2ECR_IAMInstProf.name
  connection {
    type        = "ssh"
    host        = self.public_ip
    user        = "ubuntu"
    private_key = var.private_key
    timeout     = "2m"
  }
  tags = {
    Name        = "ec2_1"
    Environment = "dev"
  }
}

resource "aws_key_pair" "Kep1" {
  key_name   = var.key_name
  public_key = var.public_key
}

resource "aws_security_group" "SG1" {
  egress = [
    {
      cidr_blocks      = ["0.0.0.0/0"],
      description      = "OutBound Connection for our EC2 Instance"
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
      from_port        = 22
      to_port          = 22
      ipv6_cidr_blocks = []
      security_groups  = []
      self             = false
      prefix_list_ids  = []
      protocol         = "tcp"
      description      = "Allow SSH inbout traffic to our EC2"
    },
    {
      cidr_blocks      = ["0.0.0.0/0"]
      from_port        = 80
      to_port          = 80
      protocol         = "tcp"
      prefix_list_ids  = []
      self             = false
      ipv6_cidr_blocks = []
      security_groups  = []
      description      = "Allow HTTP inbout traffic to our EC2"
    }
  ]
}

resource "aws_iam_instance_profile" "EC2ECR_IAMInstProf" {
  name = "EC2ECR_IAMInstProf"
  role = "EC2ECR-AUTH"
}

output "instance_public_ip" {
  value     = aws_instance.server.public_ip
  sensitive = true
}