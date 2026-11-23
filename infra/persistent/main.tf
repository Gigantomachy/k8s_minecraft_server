# Things that must survive `terraform destroy` of the server stack:
# the world volume, the public IP, daily backups, and a budget alarm.

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile

  default_tags {
    tags = {
      Project   = "k8s-minecraft"
      Stack     = "persistent"
      ManagedBy = "terraform"
    }
  }
}

# -------------------------------------------------------------------
# World data volume
# -------------------------------------------------------------------
resource "aws_ebs_volume" "world" {
  availability_zone = var.availability_zone
  size              = var.data_volume_size_gb
  type              = "gp3"
  encrypted         = true

  tags = {
    Name = "minecraft-world"
    # The snapshot policy below backs up every volume with this tag.
    Snapshot = "minecraft-daily"
  }

  # Extra safety: Terraform refuses to delete this volume.
  # To really delete it, remove this block first.
  # lifecycle {
  #   prevent_destroy = true
  # }
}

# -------------------------------------------------------------------
# Stable public IP, so the server address never changes.
# Note: AWS charges for public IPv4 addresses (~$3.60/month), even
# while the instance is stopped.
# -------------------------------------------------------------------
resource "aws_eip" "minecraft" {
  domain = "vpc"

  tags = {
    Name = "minecraft-server"
  }
}

# -------------------------------------------------------------------
# Daily snapshots (Data Lifecycle Manager)
# -------------------------------------------------------------------
data "aws_iam_policy_document" "dlm_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["dlm.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "dlm" {
  name_prefix        = "minecraft-dlm-"
  assume_role_policy = data.aws_iam_policy_document.dlm_assume.json
}

resource "aws_iam_role_policy_attachment" "dlm" {
  role       = aws_iam_role.dlm.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSDataLifecycleManagerServiceRole"
}

resource "aws_dlm_lifecycle_policy" "daily" {
  description        = "Daily snapshots of the Minecraft world volume"
  execution_role_arn = aws_iam_role.dlm.arn
  state              = "ENABLED"

  policy_details {
    resource_types = ["VOLUME"]

    target_tags = {
      Snapshot = "minecraft-daily"
    }

    schedule {
      name      = "daily"
      copy_tags = true

      create_rule {
        interval      = 24
        interval_unit = "HOURS"
        times         = ["08:00"] # UTC = 3 AM Toronto (4 AM in summer)
      }

      retain_rule {
        count = var.snapshot_retention_days
      }
    }
  }
}

# -------------------------------------------------------------------
# Budget alarm for the whole account (optional)
# -------------------------------------------------------------------
# resource "aws_budgets_budget" "monthly" {
#   count = var.alert_email == null ? 0 : 1

#   name         = "monthly-account-budget"
#   budget_type  = "COST"
#   limit_amount = tostring(var.monthly_budget_usd)
#   limit_unit   = "USD"
#   time_unit    = "MONTHLY"

#   notification {
#     comparison_operator        = "GREATER_THAN"
#     threshold                  = 50
#     threshold_type             = "PERCENTAGE"
#     notification_type          = "ACTUAL"
#     subscriber_email_addresses = [var.alert_email]
#   }

#   notification {
#     comparison_operator        = "GREATER_THAN"
#     threshold                  = 100
#     threshold_type             = "PERCENTAGE"
#     notification_type          = "ACTUAL"
#     subscriber_email_addresses = [var.alert_email]
#   }

#   notification {
#     comparison_operator        = "GREATER_THAN"
#     threshold                  = 100
#     threshold_type             = "PERCENTAGE"
#     notification_type          = "FORECASTED"
#     subscriber_email_addresses = [var.alert_email]
#   }
# }
