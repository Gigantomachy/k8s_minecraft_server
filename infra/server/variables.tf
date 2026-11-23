# --- AWS ------------------------------------------------------------

variable "aws_region" {
  description = "Must match the persistent stack's region."
  type        = string
  default     = "ca-central-1"
}

variable "aws_profile" {
  description = "Named AWS CLI profile to use. null = the default credentials."
  type        = string
  default     = null
}

# --- Instance -------------------------------------------------------

variable "instance_type" {
  description = "t3.medium (4 GB) is enough for a few players. t3.large (8 GB) for more headroom."
  type        = string
  default     = "t3.medium"
}

variable "architecture" {
  description = "x86_64 for t3/m7i etc., arm64 for t4g/m7g etc. Must match instance_type."
  type        = string
  default     = "x86_64"

  validation {
    condition     = contains(["x86_64", "arm64"], var.architecture)
    error_message = "architecture must be x86_64 or arm64."
  }
}

variable "cpu_credits" {
  description = <<-EOT
    For burstable (t3/t4g) instances.
    "standard"  = CPU is throttled when burst credits run out; never costs extra.
    "unlimited" = no throttling, but sustained high CPU is billed extra.
  EOT
  type        = string
  default     = "standard"
}

# --- Admin access ---------------------------------------------------

variable "ssh_allowed_cidr" {
  description = "Your IP for SSH, e.g. \"203.0.113.10/32\". null = port 22 stays closed (use SSM instead)."
  type        = string
  default     = null
}

variable "ssh_public_key" {
  description = "Contents of your SSH public key (e.g. ~/.ssh/id_ed25519.pub). null = no key pair."
  type        = string
  default     = null
}

# --- Minecraft ------------------------------------------------------

variable "image_tag" {
  description = "Tag of the itzg/minecraft-server image. The image picks the right Java for the game version."
  type        = string
  default     = "latest"
}

variable "minecraft_version" {
  description = "Game version, e.g. \"26.3\", or \"LATEST\". Players must run the same version."
  type        = string
  default     = "LATEST"
}

variable "memory" {
  description = "Java heap size. Leave ~1.5 GB for the OS: \"2G\" on t3.medium, \"5G\" on t3.large."
  type        = string
  default     = "2G"
}

variable "whitelist" {
  description = "Minecraft usernames allowed to join."
  type        = list(string)
}

variable "ops" {
  description = "Minecraft usernames with operator (admin) powers in-game."
  type        = list(string)
  default     = []
}

variable "motd" {
  description = "Message shown in the server list."
  type        = string
  default     = "k8s-minecraft"
}
