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
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_iam_instance_profile" "EC2ECR_IAMInstProf" {
  name = "EC2ECR_IAMInstProf"
  role = "EC2ECR-AUTH"
}

resource "aws_cloudwatch_log_group" "app" {
  name              = "/cicd/node-app"
  retention_in_days = 30
}

resource "aws_sns_topic" "alerts" {
  name = "cicd-alerts"
}

resource "aws_sns_topic_subscription" "alerts_email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alerts_email
}

resource "aws_cloudwatch_metric_alarm" "status_check" {
  alarm_name          = "cicd-ec2-status-check"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Minimum" // 0->failed  1=>passed:     5min => 4:  0 ,0, 1, 1 => 0    1, 1, 1, 1 => 1
  threshold           = 0
  dimensions          = { InstanceId = aws_instance.server.id }
  alarm_actions       = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "cpu_sustained" {
  alarm_name          = "cicd-ec2-cpu-sustained"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  dimensions          = { InstanceId = aws_instance.server.id }
  alarm_actions       = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_dashboard" "app" {
  dashboard_name = "cicd-app"
  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [["AWS/EC2", "CPUUtilization", "InstanceId", aws_instance.server.id]]
          title   = "CPU (5-min)"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/EC2", "NetworkIn", "InstanceId", aws_instance.server.id],
            ["AWS/EC2", "NetworkOut", "InstanceId", aws_instance.server.id]
          ]
          title = "Network"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/EC2", "DiskReadBytes", "InstanceId", aws_instance.server.id],
            ["AWS/EC2", "DiskWriteBytes", "InstanceId", aws_instance.server.id]
          ]
          title = "Disk I/O"
        }
      },
      {
        type   = "log"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          logGroupNames = [aws_cloudwatch_log_group.app.name]
          title         = "App logs"
        }
      }
    ]
  })
}

output "instance_id" {
  value       = aws_instance.server.id
  description = "EC2 instance ID used as the Systems Manager command target"
}