variable "aws_region" {
  description = "AWS region for everything in this project."
  type        = string
  default     = "ca-central-1"
}

variable "aws_profile" {
  description = "Named AWS CLI profile to use. null = the default credentials."
  type        = string
  default     = null
}

variable "availability_zone" {
  description = "AZ for the world volume. The server MUST run in this same AZ (EBS can't cross AZs)."
  type        = string
  default     = "ca-central-1a"
}

variable "data_volume_size_gb" {
  description = "Size of the EBS volume holding the Minecraft world."
  type        = number
  default     = 20
}

variable "snapshot_retention_days" {
  description = "How many daily snapshots of the world volume to keep."
  type        = number
  default     = 7
}

variable "alert_email" {
  description = "Email for budget alerts. null = don't create a budget."
  type        = string
  default     = null
}

variable "monthly_budget_usd" {
  description = "Monthly budget (whole AWS account) that triggers alert emails."
  type        = number
  default     = 30
}
