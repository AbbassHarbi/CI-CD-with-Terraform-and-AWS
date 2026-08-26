variable "region" {
  description = "AWS region for project resources"
  type        = string
  default     = "us-east-1"
}

variable "alerts_email" {
  description = "Email address for the CI/CD alerts SNS subscription"
  type        = string
  sensitive   = true
}