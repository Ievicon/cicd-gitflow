# Terraform — Two EC2 Servers (dev + prod)

Provisions **two Ubuntu EC2 instances** (dev + prod), each with Nginx pre-installed,
a fresh SSH key, and a security group that locks SSH to **your IP only** and opens
HTTP to the web. Outputs everything you need for the GitHub Actions pipeline.

## What it creates
```
Default VPC
 ├── Security Group: SSH(22)←your IP only,  HTTP(80)←world,  egress all
 ├── SSH key pair (private key saved locally as cicd-frontend-key.pem)
 ├── EC2  cicd-frontend-dev   (Ubuntu 22.04, t3.micro, nginx)
 └── EC2  cicd-frontend-prod  (Ubuntu 22.04, t3.micro, nginx)
```

## Files
| File | Purpose |
|---|---|
| `00-providers.tf` | aws/tls/local providers |
| `variables.tf` | region, instance type, your IP, env list |
| `01-keypair.tf` | generates SSH key, saves private key locally |
| `02-network.tf` | default VPC + security group |
| `03-ec2.tf` | the two EC2 instances (for_each over dev/prod) |
| `outputs.tf` | IPs, URLs, SSH commands, key path |

## Usage
```bash
cd terraform

# 1) set your IP so SSH is locked to you
cp terraform.tfvars.example terraform.tfvars
echo "my_ip = \"$(curl -s ifconfig.me)/32\""   # paste this value into terraform.tfvars

# 2) provision
terraform init
terraform plan
terraform apply        # type 'yes'

# 3) see outputs
terraform output
```

## After apply — wire the pipeline
`terraform output` gives you:
- `server_public_ips` → use **dev** IP as `SSH_HOST` in the **development** env,
  **prod** IP as `SSH_HOST` in the **production** env.
- `ssh_user` → `ubuntu` (the `SSH_USER` secret).
- `private_key_file` → open `cicd-frontend-key.pem`, copy its FULL contents into the
  `SSH_KEY` secret of BOTH environments.

Test it: open the `server_urls` in a browser — you'll see the placeholder page until
the pipeline deploys your React build.

## Cost
- `t3.micro` ×2 ≈ Free Tier eligible (750 hrs/mo for 12 months covers one; two micros
  may slightly exceed if both run 24/7). Realistically a few cents/hr if outside free tier.
- **Tear down when done** to stop all charges:
```bash
terraform destroy     # type 'yes'
```

## Security notes
- SSH is restricted to your IP (`my_ip`). If your IP changes, update `terraform.tfvars`
  and `terraform apply` again.
- Root EBS volume is encrypted.
- The private key and `terraform.tfvars` are git-ignored — never commit them.
