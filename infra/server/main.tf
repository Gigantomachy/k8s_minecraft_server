# The disposable part: instance, firewall, IAM role, and the attachments
# that connect it to the persistent volume and IP.
# `terraform destroy` here never touches the world data.

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile

  default_tags {
    tags = {
      Project   = "k8s-minecraft"
      Stack     = "server"
      ManagedBy = "terraform"
    }
  }
}

# -------------------------------------------------------------------
# Read outputs from the persistent stack (local state file)
# -------------------------------------------------------------------
data "terraform_remote_state" "persistent" {
  backend = "local"
  config = {
    path = "${path.module}/../persistent/terraform.tfstate"
  }
}

locals {
  persistent = data.terraform_remote_state.persistent.outputs

  # On current instance types EBS volumes show up as NVMe devices, and
  # Linux exposes a stable path containing the volume ID (without the dash).
  volume_serial = replace(local.persistent.data_volume_id, "-", "")
}

# -------------------------------------------------------------------
# Network: default VPC, default subnet in the volume's AZ
# -------------------------------------------------------------------
data "aws_vpc" "default" {
  default = true
}

data "aws_subnet" "selected" {
  vpc_id            = data.aws_vpc.default.id
  availability_zone = local.persistent.availability_zone
  default_for_az    = true
}

# -------------------------------------------------------------------
# Latest Amazon Linux 2023 image
# -------------------------------------------------------------------
data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-${var.architecture}"
}

# -------------------------------------------------------------------
# Firewall
# -------------------------------------------------------------------
resource "aws_security_group" "minecraft" {
  name_prefix = "minecraft-server-"
  description = "Minecraft game port, optional SSH"
  vpc_id      = data.aws_vpc.default.id

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "minecraft" {
  security_group_id = aws_security_group.minecraft.id
  description       = "Minecraft Java Edition"
  ip_protocol       = "tcp"
  from_port         = 25565
  to_port           = 25565
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  count = var.ssh_allowed_cidr == null ? 0 : 1

  security_group_id = aws_security_group.minecraft.id
  description       = "SSH from admin IP only"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = var.ssh_allowed_cidr
}

# Outbound: needed for package installs, Docker image pulls,
# Minecraft account checks and SSM.
resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.minecraft.id
  description       = "All outbound"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# -------------------------------------------------------------------
# Optional SSH key pair
# -------------------------------------------------------------------
resource "aws_key_pair" "admin" {
  count = var.ssh_public_key == null ? 0 : 1

  key_name_prefix = "minecraft-admin-"
  public_key      = var.ssh_public_key
}

# -------------------------------------------------------------------
# IAM role: lets you open a shell through SSM Session Manager
# (no open port 22 needed)
# -------------------------------------------------------------------
data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "minecraft" {
  name_prefix        = "minecraft-server-"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.minecraft.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "minecraft" {
  name_prefix = "minecraft-server-"
  role        = aws_iam_role.minecraft.name
}

# -------------------------------------------------------------------
# The instance
# -------------------------------------------------------------------
resource "aws_instance" "minecraft" {
  ami                    = data.aws_ssm_parameter.al2023.insecure_value
  instance_type          = var.instance_type
  subnet_id              = data.aws_subnet.selected.id
  vpc_security_group_ids = [aws_security_group.minecraft.id]
  iam_instance_profile   = aws_iam_instance_profile.minecraft.name
  key_name               = var.ssh_public_key == null ? null : aws_key_pair.admin[0].key_name

  user_data = templatefile("${path.module}/templates/user_data.sh.tftpl", {
    volume_id         = local.persistent.data_volume_id
    volume_serial     = local.volume_serial
    image_tag         = var.image_tag
    minecraft_version = var.minecraft_version
    memory            = var.memory
    whitelist         = join(",", var.whitelist)
    ops               = join(",", var.ops)
    motd              = var.motd
  })

  # user_data only runs on first boot, so a change means "rebuild the
  # instance". Safe, because the world lives on the separate volume.
  user_data_replace_on_change = true

  credit_specification {
    cpu_credits = var.cpu_credits
  }

  # Require IMDSv2 (blocks a common credential-theft trick).
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    encrypted             = true
    delete_on_termination = true
  }

  tags = {
    Name = "minecraft-server"
  }

  lifecycle {
    # Don't rebuild the server every time Amazon publishes a new AMI.
    # Rebuild on purpose with: terraform apply -replace=aws_instance.minecraft
    ignore_changes = [ami]
  }
}

# -------------------------------------------------------------------
# Connect the persistent volume and IP
# -------------------------------------------------------------------
resource "aws_volume_attachment" "world" {
  device_name = "/dev/sdf"
  volume_id   = local.persistent.data_volume_id
  instance_id = aws_instance.minecraft.id

  # Stop the instance (clean shutdown, world saved) before detaching.
  stop_instance_before_detaching = true
}

resource "aws_eip_association" "minecraft" {
  instance_id   = aws_instance.minecraft.id
  allocation_id = local.persistent.eip_allocation_id
}
