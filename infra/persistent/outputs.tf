# The server stack reads these via terraform_remote_state.

output "aws_region" {
  value = var.aws_region
}

output "availability_zone" {
  value = aws_ebs_volume.world.availability_zone
}

output "data_volume_id" {
  value = aws_ebs_volume.world.id
}

output "eip_allocation_id" {
  value = aws_eip.minecraft.allocation_id
}

output "eip_public_ip" {
  description = "The address players connect to."
  value       = aws_eip.minecraft.public_ip
}
