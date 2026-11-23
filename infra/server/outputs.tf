output "instance_id" {
  value = aws_instance.minecraft.id
}

output "server_address" {
  description = "Enter this in Minecraft: Multiplayer -> Add Server."
  value       = "${local.persistent.eip_public_ip}:25565"
}

output "ssm_shell" {
  description = "Open a shell on the instance (needs the Session Manager plugin for the AWS CLI)."
  value       = "aws ssm start-session --region ${var.aws_region} --target ${aws_instance.minecraft.id}"
}

output "ssh_command" {
  value = var.ssh_public_key == null ? "SSH disabled (no key pair)" : "ssh ec2-user@${local.persistent.eip_public_ip}"
}
