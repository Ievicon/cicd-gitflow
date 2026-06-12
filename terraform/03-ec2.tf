# --- Latest Ubuntu 22.04 LTS AMI (Canonical) ----------------------------------
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# --- Two EC2 instances: one per environment (dev, prod) -----------------------
resource "aws_instance" "server" {
  for_each = toset(var.environments)

  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.this.key_name
  vpc_security_group_ids = [aws_security_group.web.id]

  # Install + start nginx on first boot so the VM is ready for the pipeline.
  user_data = <<-EOF
    #!/bin/bash
    set -e
    apt-get update -y
    apt-get install -y nginx
    systemctl enable --now nginx
    echo "<h1>${var.project} - ${each.key} server ready</h1>" > /var/www/html/index.html
  EOF

  root_block_device {
    volume_size = 8 # GB — Free Tier allows up to 30GB total
    volume_type = "gp3"
    encrypted   = true
  }

  tags = {
    Name        = "${var.project}-${each.key}"
    Environment = each.key
    Project     = var.project
  }
}
