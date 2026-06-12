# --- Networking: use the account's DEFAULT VPC (keeps this simple & cheap) ----
data "aws_vpc" "default" {
  default = true
}

# --- Security group: SSH locked to YOUR IP, HTTP open (configurable) ----------
resource "aws_security_group" "web" {
  name        = "${var.project}-web-sg"
  description = "Allow SSH from my IP and HTTP from the world"
  vpc_id      = data.aws_vpc.default.id

  # SSH — ONLY from your IP (security best practice; never 0.0.0.0/0 for SSH)
  ingress {
    description = "SSH from my IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  # HTTP — the website
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.allow_http_from]
  }

  # All outbound allowed (so the VM can apt-install nginx, pull updates, etc.)
  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Project = var.project }
}
