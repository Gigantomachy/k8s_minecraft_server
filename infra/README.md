# infra

Two separate Terraform stacks, each with its own state:

| Stack | Contains | Destroy it? |
|---|---|---|
| `persistent/` | World EBS volume, Elastic IP, daily snapshots, budget alarm | Almost never (the volume has `prevent_destroy`) |
| `server/` | EC2 instance, security group, IAM role, volume and IP attachments | Any time. The world is safe |

`server/` reads `persistent/terraform.tfstate`, so apply `persistent/` first.

## First-time setup

```bash
cd infra/persistent
cp terraform.tfvars.example terraform.tfvars   # edit values
terraform init
terraform apply

cd ../server
cp terraform.tfvars.example terraform.tfvars   # add your Minecraft username
terraform init
terraform apply
```

Wait 2–3 minutes after apply for the first boot (Docker install, world
generation), then connect to the `server_address` output.

## Day to day

```bash
# Stop paying for compute when nobody's playing (volume and IP stay):
aws ec2 stop-instances  --instance-ids $(terraform -chdir=infra/server output -raw instance_id)
aws ec2 start-instances --instance-ids $(terraform -chdir=infra/server output -raw instance_id)

# Shell on the instance, no SSH needed:
$(terraform -chdir=infra/server output -raw ssm_shell)

# On the instance:
sudo docker logs -f minecraft                 # server console output
sudo docker exec -it minecraft rcon-cli       # admin console (RCON, local only)
sudo cat /var/log/minecraft-bootstrap.log     # first-boot script output

# Rebuild the server from scratch (world is kept):
terraform -chdir=infra/server apply -replace=aws_instance.minecraft
```

## Requirements

- A default VPC in the region. If yours was deleted: `aws ec2 create-default-vpc`
- For `ssm_shell`: the AWS CLI Session Manager plugin
